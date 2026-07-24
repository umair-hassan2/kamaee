# WhatsApp AI Assistant — System Design & Implementation Plan

> Tier 3 flagship feature. Shopkeeper sends a WhatsApp message (text or voice, Urdu/English/Romanized Urdu) and gets an intelligent, data-driven answer about their business.

---

## Table of Contents

1. [High-Level Architecture](#1-high-level-architecture)
2. [Data Sync Strategy](#2-data-sync-strategy)
3. [Firestore as an Aggregated Intelligence Store](#3-firestore-as-an-aggregated-intelligence-store)
4. [Sync Worker Design](#4-sync-worker-design)
5. [Intent Guardrails via Claude Tool Use](#5-intent-guardrails-via-claude-tool-use)
6. [Full Bot Request Flow](#6-full-bot-request-flow)
7. [Voice Pipeline](#7-voice-pipeline)
8. [Backend Scaffolding](#8-backend-scaffolding)
9. [Cost Model](#9-cost-model)
10. [Scaling Considerations](#10-scaling-considerations)
11. [Build Phases](#11-build-phases)

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SHOPKEEPER'S PHONE                       │
│                                                                 │
│   ┌──────────────┐   writes    ┌─────────────────────────────┐ │
│   │  Kamaae App  │────────────▶│  SQLite (local DB)          │ │
│   │  (Flutter)   │             └─────────────┬───────────────┘ │
│   └──────────────┘                           │ dual-write       │
│                                              ▼                  │
│                                  ┌───────────────────────┐     │
│                                  │  Firestore Sync Layer  │     │
│                                  │  (on every transaction)│     │
│                                  └───────────┬───────────┘     │
└──────────────────────────────────────────────┼─────────────────┘
                                               │
                          ┌────────────────────▼──────────────────┐
                          │            GOOGLE FIRESTORE            │
                          │     (aggregated intelligence store)    │
                          │                                        │
                          │  shops/{shopId}/snapshots/today        │
                          │  shops/{shopId}/inventory/{itemId}     │
                          │  shops/{shopId}/khata/summary          │
                          │  shops/{shopId}/alerts/low_stock       │
                          └────────────────┬──────────────────────┘
                                           │
                    ┌──────────────────────┘
                    │
    ┌───────────────▼──────────────────────────────────────────────┐
    │                      BACKEND (Node.js)                        │
    │                   Railway / Render (free tier)                │
    │                                                              │
    │  ┌─────────────────────────────────────────────────────┐    │
    │  │  1. Receive WhatsApp webhook                         │    │
    │  │  2. Lookup shopId by sender phone number             │    │
    │  │  3. Pass 1 → Claude (Haiku) + tool definitions       │    │
    │  │     → get structured intent + params                 │    │
    │  │  4. Fetch relevant Firestore doc(s)                  │    │
    │  │  5. Pass 2 → Claude (Haiku) + data → response text  │    │
    │  │  6. (Voice) → ElevenLabs TTS → audio note           │    │
    │  │  7. Send WhatsApp reply                              │    │
    │  └─────────────────────────────────────────────────────┘    │
    └──────────────────────────────────────────────────────────────┘
                    │                         │
         ┌──────────▼──────────┐   ┌──────────▼──────────┐
         │   Meta WhatsApp     │   │    Claude API        │
         │   Cloud API         │   │    (Anthropic)       │
         │   (webhook in/out)  │   │    Haiku model       │
         └─────────────────────┘   └─────────────────────┘
                                              │
                                   ┌──────────▼──────────┐
                                   │   ElevenLabs TTS    │
                                   │   (voice replies)   │
                                   └─────────────────────┘
```

**Key design decisions:**
- One shared WhatsApp number for all shops. Phone number → shopId lookup.
- Firestore is NOT a raw copy of SQLite. It is a pre-computed answer store.
- Claude is only given pre-aggregated data — it never queries raw transactions.
- Two Claude passes per request: one for routing (intent), one for response generation.

---

## 2. Data Sync Strategy

### The wrong model: Hourly batch sync

```
App → SQLite → [wait up to 60 min] → Firestore
```

Problem: Shopkeeper asks "what did I make today?" but last sync was 55 minutes ago. Data is stale. Unacceptable for a real-time business tool.

### The right model: Dual-write + hourly reconciliation

```
App → SQLite  (primary, always)
    ↘ Firestore  (async, on every transaction event)

Hourly worker → reconcile + re-aggregate (catches any missed writes from offline)
```

**How it works in Flutter:**

```dart
// In cart_service.dart — after every successful checkout
Future<void> checkoutCart() async {
  final sale = await _db.saveSale(cart);     // write to SQLite (primary)
  _syncToFirestore(sale);                     // fire-and-forget async write
  await _aggregateAndSync();                  // update aggregated docs
}

Future<void> _syncToFirestore(Sale sale) async {
  try {
    await firestore
      .collection('shops')
      .doc(shopId)
      .collection('events')
      .add(sale.toFirestoreMap());
  } catch (e) {
    // Silent fail — hourly worker will reconcile
    // Firestore SDK also queues writes locally when offline
  }
}
```

**Firestore handles offline automatically:** The Flutter Firestore SDK queues writes locally when the phone has no connectivity and syncs them when connection is restored. The hourly reconciliation job is a safety net, not the primary mechanism.

**The hourly reconciliation worker** (runs server-side):
- Reads last N transactions from SQLite export or Firestore events
- Re-computes all aggregated documents
- Overwrites them in Firestore
- Ensures any missed dual-writes are caught

---

## 3. Firestore as an Aggregated Intelligence Store

Every document in Firestore is a **pre-computed answer** to a question the bot might be asked. The bot reads documents — it never computes.

### Document Structure

```
shops/
└── {shopId}/
    │
    ├── meta/
    │   └── profile              ← shop name, owner name, phone, currency, locale
    │
    ├── snapshots/
    │   ├── today                ← computed from midnight to now
    │   ├── yesterday
    │   ├── this_week            ← Monday to now
    │   ├── last_week            ← full previous week
    │   └── this_month
    │
    ├── inventory/               ← collection (one doc per item)
    │   └── {itemId}
    │
    ├── khata/                   ← collection
    │   ├── summary              ← totals + top debtors list
    │   └── {customerId}
    │
    └── alerts/
        ├── low_stock            ← pre-filtered, ready to read
        └── overdue_khata        ← 30+ day unpaid, ready to read
```

### Document Schemas

**`snapshots/today`**
```json
{
  "date": "2026-07-25",
  "revenue": 12400,
  "profit": 3100,
  "margin_pct": 25.0,
  "tx_count": 47,
  "avg_basket": 263.8,
  "top_sellers": [
    {"name": "Lays 100g", "qty_sold": 18, "revenue": 900},
    {"name": "Pepsi 1.5L", "qty_sold": 12, "revenue": 1080}
  ],
  "vs_yesterday": {
    "revenue_delta_pct": 12.5,
    "profit_delta_pct": 8.2
  },
  "synced_at": "2026-07-25T14:32:00Z"
}
```

**`inventory/{itemId}`**
```json
{
  "id": "item_001",
  "name": "Lays 100g",
  "current_stock": 24,
  "purchase_price": 40,
  "selling_price": 50,
  "margin_pct": 20.0,
  "avg_daily_sales": 6.2,
  "days_to_stockout": 3.9,
  "is_low_stock": true,
  "last_restocked_at": "2026-07-20T10:00:00Z"
}
```

**`khata/summary`**
```json
{
  "total_outstanding": 8200,
  "active_debtors": 12,
  "overdue_count": 3,
  "top_debtors": [
    {"name": "Ahmed Bhai", "outstanding": 2400, "days_overdue": 45},
    {"name": "Rashid", "outstanding": 1800, "days_overdue": 12}
  ]
}
```

**`alerts/low_stock`**
```json
{
  "items": [
    {"name": "Lays 100g", "stock": 2, "days_left": 0.3},
    {"name": "Pepsi 1.5L", "stock": 1, "days_left": 0.1},
    {"name": "Colgate", "stock": 0, "days_left": 0}
  ],
  "count": 3,
  "generated_at": "2026-07-25T14:32:00Z"
}
```

### What the bot reads per intent

| Question type | Firestore reads |
|---|---|
| "Aaj kitna hua?" | `snapshots/today` |
| "Kya khatam ho raha hai?" | `alerts/low_stock` |
| "Khata kaisa hai?" | `khata/summary` |
| "Is hafte ka hisaab?" | `snapshots/this_week` |
| "Best sellers?" | `snapshots/today` (top_sellers already embedded) |
| "Margin analysis?" | `inventory/*` (scan all items, ~20-30 docs) |

Maximum 3-4 reads per query. Firestore free tier is 50k reads/day. At 100 shops × 10 messages = 1,000 reads/day — 2% of the free quota.

---

## 4. Sync Worker Design

The worker is the brain that keeps Firestore accurate and pre-computed.

```
┌─────────────────────────────────────────────────────────────┐
│                      SYNC WORKER                            │
│                                                             │
│  Triggers:                                                  │
│  • Event-driven: app fires after every sale/restock/khata  │
│  • Hourly: scheduled cron as reconciliation safety net      │
│                                                             │
│  Steps:                                                     │
│  1. Read SQLite data (via export or direct query)           │
│  2. Compute all aggregates                                  │
│  3. Write to Firestore atomically (batch write)             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Pseudo-implementation (Python or Node.js):**

```python
def sync_shop(shop_id: str, db: SQLiteConnection):
    now = datetime.now()
    today = now.date()

    # --- Transactions ---
    today_txns = db.query(
        "SELECT * FROM transactions WHERE DATE(created_at) = ?", today
    )
    yesterday_txns = db.query(
        "SELECT * FROM transactions WHERE DATE(created_at) = ?", today - timedelta(days=1)
    )
    week_txns = db.query(
        "SELECT * FROM transactions WHERE created_at >= ?", start_of_week()
    )

    # --- Compute snapshots ---
    def aggregate(txns):
        revenue = sum(t.total for t in txns)
        profit = sum(t.profit for t in txns)
        return {
            "revenue": revenue,
            "profit": profit,
            "margin_pct": (profit / revenue * 100) if revenue > 0 else 0,
            "tx_count": len(txns),
            "avg_basket": revenue / len(txns) if txns else 0,
            "top_sellers": compute_top_sellers(txns, limit=5),
        }

    today_snap = aggregate(today_txns)
    yesterday_snap = aggregate(yesterday_txns)

    # Add WoW delta
    today_snap["vs_yesterday"] = {
        "revenue_delta_pct": pct_change(yesterday_snap["revenue"], today_snap["revenue"]),
        "profit_delta_pct": pct_change(yesterday_snap["profit"], today_snap["profit"]),
    }

    # --- Compute inventory with intelligence ---
    items = db.query("SELECT * FROM items")
    inventory_docs = []
    low_stock_items = []

    for item in items:
        avg_daily = compute_avg_daily_sales(db, item.id, days=14)
        days_left = item.stock / avg_daily if avg_daily > 0 else 999
        is_low = days_left < 7 or item.stock == 0

        doc = {
            **item.to_dict(),
            "margin_pct": (item.selling - item.purchase) / item.selling * 100,
            "avg_daily_sales": avg_daily,
            "days_to_stockout": round(days_left, 1),
            "is_low_stock": is_low,
        }
        inventory_docs.append(doc)

        if is_low:
            low_stock_items.append({
                "name": item.name,
                "stock": item.stock,
                "days_left": round(days_left, 1),
            })

    # --- Compute khata ---
    customers = db.query("SELECT * FROM customers WHERE outstanding > 0")
    khata_summary = {
        "total_outstanding": sum(c.outstanding for c in customers),
        "active_debtors": len(customers),
        "overdue_count": len([c for c in customers if c.days_since_payment > 30]),
        "top_debtors": sorted(customers, key=lambda c: -c.outstanding)[:5],
    }

    # --- Batch write to Firestore ---
    batch = firestore.batch()
    shop_ref = firestore.collection("shops").document(shop_id)

    batch.set(shop_ref.collection("snapshots").document("today"), today_snap)
    batch.set(shop_ref.collection("snapshots").document("yesterday"), yesterday_snap)
    batch.set(shop_ref.collection("snapshots").document("this_week"), aggregate(week_txns))
    batch.set(shop_ref.collection("alerts").document("low_stock"), {"items": low_stock_items})
    batch.set(shop_ref.collection("khata").document("summary"), khata_summary)

    for doc in inventory_docs:
        batch.set(shop_ref.collection("inventory").document(doc["id"]), doc)

    batch.commit()
```

---

## 5. Intent Guardrails via Claude Tool Use

### The core insight

Claude's tool use IS the intent classifier. You don't build a separate classification system. You define a finite set of tools (intents), force Claude to pick one, and use the tool call as structured routing output.

The key API flag is `tool_choice: {"type": "any"}` — this forces Claude to always invoke a tool. It cannot free-form respond. Every call returns typed JSON.

### Tool Definitions

```python
TOOLS = [
    {
        "name": "get_sales_summary",
        "description": "Get revenue, profit, transaction count, and top sellers for a time period. Use for questions about how much was earned, sales performance, or business overview.",
        "input_schema": {
            "type": "object",
            "properties": {
                "period": {
                    "type": "string",
                    "enum": ["today", "yesterday", "this_week", "last_week", "this_month"],
                    "description": "The time period to query"
                }
            },
            "required": ["period"]
        }
    },
    {
        "name": "get_inventory_status",
        "description": "Get current stock levels, low-stock alerts, and days-to-stockout for items. Use for questions about what's running low, what to restock, or stock quantities.",
        "input_schema": {
            "type": "object",
            "properties": {
                "filter": {
                    "type": "string",
                    "enum": ["all", "low_stock", "out_of_stock"],
                    "description": "Filter inventory by stock status"
                }
            },
            "required": ["filter"]
        }
    },
    {
        "name": "get_khata_overview",
        "description": "Get outstanding credit balances owed by customers. Use for questions about who owes money, total credit outstanding, or overdue payments.",
        "input_schema": {
            "type": "object",
            "properties": {
                "filter": {
                    "type": "string",
                    "enum": ["all", "overdue", "top_debtors"],
                }
            },
            "required": ["filter"]
        }
    },
    {
        "name": "get_top_sellers",
        "description": "Get best-selling items ranked by quantity sold or revenue generated.",
        "input_schema": {
            "type": "object",
            "properties": {
                "period": {"type": "string", "enum": ["today", "this_week", "this_month"]},
                "by": {"type": "string", "enum": ["quantity", "revenue"]}
            },
            "required": ["period", "by"]
        }
    },
    {
        "name": "get_profit_analysis",
        "description": "Get profit margin analysis across all inventory items — which items earn the most, which are low margin.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "out_of_scope",
        "description": "The user asked about something not related to their shop business (weather, news, sports, general knowledge, etc.). Use this when no other tool applies.",
        "input_schema": {"type": "object", "properties": {}}
    }
]
```

### Why this beats a custom classifier

| Custom Classifier | Claude Tool Use |
|---|---|
| Needs training data | Zero training — works on day 1 |
| Breaks on Urdu/Romanized Urdu | Claude handles multilingual naturally |
| Binary yes/no | Returns structured params too (e.g. `period: "this_week"`) |
| Separate system to maintain | One API call |
| Can't handle novel phrasings | Generalizes from intent description |

### Two-pass request flow

```
Pass 1 — Routing (Claude Haiku, ~0.5s)
─────────────────────────────────────
Input:  user_message + TOOLS + system prompt
Output: tool_call { name: "get_sales_summary", input: { period: "today" } }
Cost:   ~$0.00008 per call

        ↓ use tool_name + tool_args to fetch Firestore data

Pass 2 — Response Generation (Claude Haiku, ~1.5s)
────────────────────────────────────────────────────
Input:  user_message + tool_result (Firestore data) + system prompt
Output: natural language reply (Urdu or English matching user's language)
Cost:   ~$0.0002 per call
```

---

## 6. Full Bot Request Flow

### Text message flow

```
Shopkeeper types: "Aaj kitna hua?"
        │
        ▼
┌───────────────────────────────┐
│  Meta WhatsApp Cloud API      │
│  POST /webhook                │
│  { from: "+923001234567",     │
│    message: "Aaj kitna hua?" }│
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│  Lookup: phone → shopId       │
│  "+923001234567" → "shop_abc" │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────────────────────────────┐
│  PASS 1: Intent Routing                               │
│                                                       │
│  Claude Haiku + TOOLS + tool_choice: "any"            │
│                                                       │
│  → returns:                                           │
│  {                                                    │
│    "name": "get_sales_summary",                       │
│    "input": { "period": "today" }                     │
│  }                                                    │
└───────────────────────────────┬───────────────────────┘
                                │
                                ▼
                   ┌────────────────────────┐
                   │  out_of_scope?         │
                   │  → send refusal        │
                   │  → done                │
                   └────────────┬───────────┘
                                │ no
                                ▼
┌───────────────────────────────────────────────────────┐
│  Firestore Read                                       │
│                                                       │
│  fetch shops/shop_abc/snapshots/today                 │
│  (in-memory cache hit if same shop queried recently)  │
└───────────────────────────────┬───────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────┐
│  PASS 2: Response Generation                          │
│                                                       │
│  Claude Haiku + Firestore data                        │
│  System: "Reply in same language as user. Concise."  │
│                                                       │
│  → returns:                                           │
│  "Aaj ka hisaab:                                      │
│   Revenue: PKR 12,400                                 │
│   Munafa: PKR 3,100 (25%)                             │
│   Transactions: 47                                    │
│   Kal se 12.5% zyada 📈"                              │
└───────────────────────────────┬───────────────────────┘
                                │
                                ▼
                   WhatsApp reply sent
                   Total latency: ~2-3 seconds
```

### Caching layer (simple, effective)

```
Backend in-memory cache:
  Key: shopId
  Value: { firestore_docs, fetched_at }
  TTL: 5 minutes

On Firestore fetch:
  if cache[shopId] exists and age < 5min → use cache
  else → fetch Firestore, update cache

Benefit: 5 messages in a conversation burst → only 1 Firestore read
```

No vector similarity search for V1. The bottleneck is Claude API cost, not Firestore reads. Similarity caching would add significant complexity with minimal ROI at this scale.

---

## 7. Voice Pipeline

### Flow

```
Shopkeeper sends voice note
        │
        ▼
┌───────────────────────────────┐
│  WhatsApp media download URL  │
│  GET /media/{media_id}        │
│  → download .ogg audio file   │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│  OpenAI Whisper API           │
│  Input: .ogg audio            │
│  Output: transcribed text     │
│  Supports: Urdu, English      │
│  Cost: ~$0.006/minute         │
│  Latency: ~1-2 seconds        │
└───────────────┬───────────────┘
                │
                ▼
        [same as text flow]
        Pass 1 → routing
        Firestore fetch
        Pass 2 → response text
                │
                ▼
┌───────────────────────────────┐
│  ElevenLabs TTS               │
│  Input: response text         │
│  Output: audio stream         │
│  → encode as .ogg             │
│  → upload to WhatsApp media   │
│  → send as voice note reply   │
└───────────────────────────────┘
```

### Latency breakdown

| Step | Time |
|---|---|
| WhatsApp media download | ~0.5s |
| Whisper transcription | ~1-2s |
| Pass 1 (intent routing) | ~0.5s |
| Firestore fetch | ~0.2s |
| Pass 2 (response gen) | ~1.5s |
| ElevenLabs TTS | ~2-3s |
| WhatsApp media upload + send | ~0.5s |
| **Total** | **~6-8 seconds** |

### Latency optimization

**Stream Claude → ElevenLabs in parallel:**

```
Claude Pass 2 starts streaming output
       │
       ├─ sentence 1 arrives → immediately send to ElevenLabs
       ├─ sentence 2 arrives → append to ElevenLabs stream
       └─ done → ElevenLabs finalizes audio

Net saving: ~1.5-2 seconds (ElevenLabs processes while Claude is still generating)
Effective latency: ~4-5 seconds
```

**Immediate acknowledgement message:**

Send a text message instantly upon receiving the voice note: *"Sun raha hoon... ek second"* — then follow up with the voice reply. This resets the user's patience threshold.

---

## 8. Backend Scaffolding

### Stack

- **Runtime**: Node.js (TypeScript) or Python — either works. Node.js is slightly better for streaming.
- **Hosting**: Railway or Render free tier (sufficient for initial scale). Serverless (Vercel Functions / Cloud Functions) is also viable — no cold-start issue since WhatsApp webhooks are not latency-critical to the millisecond.
- **Webhook**: Express (Node) or FastAPI (Python)
- **Firestore SDK**: `@google-cloud/firestore` or `firebase-admin`
- **Claude SDK**: `@anthropic-ai/sdk`
- **WhatsApp**: `axios` calls to Meta Graph API (no official SDK needed)

### Phone number → shopId registration flow

```
New shopkeeper registers in Kamaae app
        │
        ▼
App saves their phone number in Firestore:
  phone_registry/{normalizedPhone} → { shopId, shopName, registeredAt }
        │
        ▼
When WhatsApp message arrives:
  sender = "+923001234567"
  shopId = firestore.get("phone_registry/" + normalize(sender))
  if not found → reply "Please register in the Kamaae app first"
```

### Backend route structure

```
POST /webhook/whatsapp        ← Meta webhook (messages in)
GET  /webhook/whatsapp        ← Meta webhook verification (one-time setup)
POST /webhook/sync            ← Flutter app triggers on each transaction
POST /cron/reconcile          ← Hourly reconciliation (triggered by cron service)
```

### System prompt

```
You are a helpful business assistant for a small shop in Pakistan.
You ONLY answer questions about the shop's sales, inventory, khata (credit), and profits.
Always reply in the same language the shopkeeper used — Urdu, English, or Romanized Urdu.
Be concise. Use numbers. If data is from earlier today, mention when it was last updated.
Never give financial advice beyond what the data shows.
```

---

## 9. Cost Model

### Per message (text)

| Component | Cost |
|---|---|
| Claude Haiku Pass 1 (~500 tokens in, ~50 out) | ~$0.00008 |
| Claude Haiku Pass 2 (~800 tokens in, ~150 out) | ~$0.00020 |
| Firestore reads (2-4 reads) | ~$0.000001 |
| WhatsApp Cloud API (Pakistan tier, per conversation) | ~$0.0085 |
| **Total per text message** | **~$0.009** |

### Per message (voice)

| Component | Cost |
|---|---|
| Whisper (avg 15-second voice note) | ~$0.0015 |
| Claude (same as text) | ~$0.00028 |
| ElevenLabs (~100 words output, Starter tier) | ~$0.003 |
| **Total per voice message** | **~$0.005** |

### Monthly projection (100 shops, 5 messages/day each)

```
Text messages:   100 shops × 4 text msg/day × 30 days = 12,000 messages
Voice messages:  100 shops × 1 voice msg/day × 30 days = 3,000 messages

WhatsApp conversations: 100 shops × 30 days = 3,000 conversations
  - First 1,000 free → 2,000 × $0.0085 = $17

Claude + Whisper + ElevenLabs: ~$50/month

Total: ~$67/month for 100 shops
```

At this scale the product is essentially free to operate. Use Haiku aggressively — only escalate to Sonnet for complex multi-part questions (heuristic: message contains multiple question marks or conjunctions like "aur" / "and").

---

## 10. Scaling Considerations

### Actual constraints at scale

| Constraint | Free tier limit | 100 shops |
|---|---|---|
| Firestore reads | 50k/day | ~5k/day ✅ |
| Firestore writes | 20k/day | ~2k/day ✅ |
| WhatsApp Cloud API | 1k conversations/month free | 3k/month (needs payment) |
| Railway RAM | 512MB | ~50MB used ✅ |

### When to scale (not now)

- **500+ active shops**: Move backend to Cloud Run (auto-scaling), add Redis for the in-memory cache.
- **High voice load**: ElevenLabs costs become significant — consider Google TTS as a cheaper fallback for simple responses.
- **Firestore costs**: If reads exceed free tier, add aggressive caching. At 1,000 shops × 10 messages = 10k reads/day, still under free tier.

### What NOT to optimize prematurely

- Vector similarity search for response caching — adds significant complexity. Add only when Claude cost is a proven bottleneck (it won't be at <1,000 shops).
- Dedicated intent classification model — Claude tool use handles it cleanly.
- Database sharding — Firestore scales horizontally by default.

---

## 11. Build Phases

### Phase A — Data Bridge (Week 1)
- [ ] Add Firebase Firestore to Flutter app (`firebase_core`, `cloud_firestore`)
- [ ] Implement dual-write on each sale / restock / khata update
- [ ] Build sync worker script (Python or Node) that computes and writes all aggregated docs
- [ ] Set up hourly reconciliation cron (Railway cron / Cloud Scheduler)
- [ ] Define and validate all Firestore document schemas
- [ ] Test: send 10 transactions from app, verify Firestore aggregates are correct

### Phase B — Text Bot (Week 2)
- [ ] Register WhatsApp Cloud API (Meta developer account, verify business)
- [ ] Set up backend (Node.js on Railway):
  - Webhook receive + verify endpoint
  - Phone number → shopId lookup
  - Pass 1: Claude intent routing with tool use
  - Pass 2: Claude response generation
  - Firestore data fetcher per intent
  - In-memory shop data cache (5-min TTL)
  - WhatsApp reply sender
- [ ] Test all 5 intents with real shop data
- [ ] Test out-of-scope guardrail with irrelevant questions
- [ ] Test bilingual: Urdu, English, Romanized Urdu

### Phase C — Voice (Week 3)
- [ ] Whisper API integration (download WhatsApp audio, transcribe)
- [ ] ElevenLabs integration (text → voice note)
- [ ] Streaming pipeline: Claude → ElevenLabs (parallel)
- [ ] WhatsApp media upload + send as voice note
- [ ] Send immediate acknowledgement on voice note receipt
- [ ] Test end-to-end latency, target < 8 seconds

### Phase D — Polish (Week 4)
- [ ] Handle edge cases: empty data (new shop, no sales yet)
- [ ] Handle multi-part questions ("aaj ka hisaab aur kya khatam ho raha hai?")
- [ ] Add conversation memory: track last 3 messages per user for follow-up context
- [ ] Monitoring: log every intent hit + out-of-scope rate (tune if OOS > 10%)
- [ ] Usage dashboard: messages/day per shop, top intents
- [ ] Rate limiting: max 20 messages/hour per shop (prevent abuse)

---

## Quick Reference: Key Design Principles

1. **Dual-write, not batch sync** — every transaction writes to both SQLite and Firestore immediately. Hourly worker is reconciliation only.

2. **Firestore = pre-computed answers** — the sync worker aggregates everything. The bot reads, never computes.

3. **Tool use = intent classification** — `tool_choice: "any"` forces structured routing. One system, not two.

4. **Two Claude passes** — Pass 1 for routing (fast, cheap), Pass 2 for response (uses real data).

5. **Cache Firestore data, not Claude responses** — 5-min in-memory cache per shopId. Similarity search is premature optimization.

6. **Haiku by default, Sonnet by exception** — use a heuristic (multiple questions in one message) to escalate.

7. **Stream Claude → ElevenLabs** — reduces voice latency by ~2 seconds by parallelizing TTS with generation.

8. **One shared WhatsApp number** — phone number is the shop identifier. Registration links phone → shopId in Firestore.
