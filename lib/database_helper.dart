import "package:sqflite/sqflite.dart";
import "package:path/path.dart";
import "models/item.dart";

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "kamaae.db");
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      "CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, barcode TEXT UNIQUE, name TEXT, purchase_price REAL, selling_price REAL, quantity INTEGER)",
    );
  }

  Future<Item?> getItemByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query("items", where: "barcode = ?", whereArgs: [barcode]);
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert("items", item.toMap());
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return await db.update("items", item.toMap(), where: "id = ?", whereArgs: [item.id]);
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query("items", orderBy: "name COLLATE NOCASE ASC");
    return maps.map((m) => Item.fromMap(m)).toList();
  }
}
