# Kamaae — Feature Roadmap

## Current Foundation (Already Built)
- POS with barcode scanning, cart, checkout
- Inventory with low-stock alerts
- Khata (credit ledger) per customer
- Finance analytics (today / week / month)
- Cash register reconciliation
- Receipt PDF + WhatsApp share
- Daily 9 PM notification

---

## Tier 1 — Quick Wins (1–3 days each, no backend required)

### 1. Profit Margin % on Inventory List
Show margin % next to each item price. Computed as `((sellingPrice - purchasePrice) / sellingPrice) * 100`.
Color-code: red < 10%, yellow 10–25%, green > 25%.
Zero new infrastructure — purely a UI addition on the inventory list.

### 2. Smart Daily WhatsApp Report
One button that generates a rich pre-formatted WhatsApp message from today's SQLite data and opens WhatsApp ready to send. Example output:

```
📊 *Kamaae Daily Report — 20 Jul*

💰 Revenue: PKR 12,400
📈 Profit: PKR 3,100 (25% margin)
🛒 Transactions: 47

⚠️ Low Stock (3 items):
  • Lays 100g — 2 left
  • Pepsi 1.5L — 1 left
  • Colgate — 0 ❌

💳 Outstanding Khata: PKR 8,200

🔥 Top Seller: Lays 100g (18 sold)
```

Uses existing `whatsapp_share.dart` and all existing data. Delivers 80% of the AI assistant value with zero infrastructure. ~2 days.

### 3. Discount at Checkout
Add a Discount field on the cart/checkout screen — flat amount or percentage. Applies before total. Updates profit calculation in transaction log. One of the most common daily shopkeeper actions.

### 4. Khata Payment Reminders via WhatsApp
"Send Reminder" button on the customer detail screen. Opens WhatsApp with pre-filled message:
> "Assalam-o-Alaikum [Name], your outstanding balance at [Shop] is PKR X. Please settle at your convenience."

### 5. Week-over-Week Comparison in Finance
Add a `+12% vs last week` badge next to revenue and profit on the finance screen. Shopkeepers are motivated by trends more than absolute numbers. Pure SQL on existing transaction data.

---

## Tier 2 — Medium Effort (1–2 weeks each)

### 6. Sales Velocity & Days-Until-Stockout
For each inventory item: avg daily sales (from transactions) ÷ current stock = days remaining.
Show "~4 days left" on inventory items. Flag items with < 7 days remaining.
Turns the inventory list from a static snapshot into a forward-looking restock tool.

### 7. Bulk Restock Screen
When a delivery arrives, the shopkeeper currently has to tap each item individually.
Build a "Restock Batch" screen: scan/search multiple items in sequence, enter new quantities, confirm once.

### 8. Supplier Module
- Add suppliers (name, WhatsApp number, items they supply)
- Link inventory items to suppliers
- "Reorder" button on low-stock alert → pre-fills WhatsApp to supplier with item + quantity needed

Closes the loop on the restock workflow end-to-end.

### 9. Returns / Refund Flow
"Return" button on sale detail screen that:
- Reverses the transaction
- Restores stock
- Handles khata credit if it was a credit sale

Currently there's no way to handle returns at all.

### 10. iOS Build + TestFlight Distribution
The Flutter codebase already compiles to iOS. Work needed: splash screen config, permissions, entitlements, TestFlight setup.

---

## Tier 3 — WhatsApp AI Assistant (Flagship, 3–4 weeks)

The most differentiated and highest-value feature for the shopkeeper market. Shopkeepers can ask questions in natural language (or voice) and get intelligent answers about their business.

### What the bot answers
- Cash flow: today's revenue, outstanding khata, net position
- Restock: what's running low based on sales velocity, how much to order
- Best/worst sellers: this week vs last week comparisons
- Profit analysis: which items have highest margin, which are sold at a loss
- Khata: who owes the most, who hasn't paid in 30+ days
- Seasonal/demand signals: "Coke is selling 3x more — restock before weekend"

### Architecture

**Phase A — Data Bridge (Week 1)**
Add Firebase Firestore sync (free tier: 1GB storage, 50k reads/day).
App exports SQLite data to Firestore on a schedule or on-demand.
Gives the bot a data source without requiring always-on phone connectivity.

**Phase B — The Bot (Week 2)**
- WhatsApp Cloud API (Meta's official API — free for first 1,000 conversations/month)
- Lightweight Node.js or Python backend (free tier on Railway or Render)
- Flow: shopkeeper sends WhatsApp message → bot pulls Firestore data → Claude API generates insight → reply sent back

**Phase C — Voice (Week 3)**
WhatsApp supports voice messages natively.
- Shopkeeper sends voice note (Urdu/English)
- Bot downloads audio → Whisper API transcription (~$0.006/min)
- Transcription + shop data → Claude API for insight
- Claude response → TTS (ElevenLabs or Google TTS) → voice note reply

Shopkeeper asks: *"Kon si cheezein khatam ho rahi hain?"* → Bot replies with a voice note explaining what to restock, how much, and from which supplier.

---

## Build Order (Recommended)

| # | Feature | Effort | Value |
|---|---|---|---|
| 1 | Profit margin % on inventory | 1 day | High |
| 2 | Smart daily WhatsApp report | 2 days | Very High |
| 3 | Discount at checkout | 1 day | High |
| 4 | Khata payment reminder | 1 day | High |
| 5 | Week-over-week comparison | 2 days | Medium |
| 6 | Sales velocity / days-to-stockout | 3 days | Very High |
| 7 | Bulk restock screen | 2 days | High |
| 8 | Supplier module | 1 week | High |
| 9 | Returns / refund flow | 3 days | Medium |
| 10 | iOS build | 1 week | Medium |
| 11 | WhatsApp AI Assistant | 3–4 weeks | Very High (flagship) |

### Strategy
- **This week:** Ship items 1–4. All in-app, no backend, immediately useful.
- **Next 2 weeks:** Items 5–7 (sales velocity is the core intelligence layer for restocking decisions).
- **Following month:** Supplier module, returns, then begin WhatsApp AI Assistant as the flagship.
