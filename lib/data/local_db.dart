import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Base de dados local (SQLite) da app:
//  - grupos e itens: cópia dos dados do Firebase, para abrir sem rede
//  - operacoes: fila das alterações feitas na app que ainda não chegaram ao Firebase

class LocalDb {
  static Database? _db;

  // Abre a base de dados só na primeira vez que for pedida (depois reutiliza)
  static Future<Database> get db async {
    _db ??= await _abrir();
    return _db!;
  }

  static Future<Database> _abrir() async{
    final caminho = join(await getDatabasesPath(), 'dja_konta.db');

    return openDatabase(
      caminho, 
      version: 1,

      // só corre quando a base de dados ainda não existe no telemóvel
      onCreate: (db, version) async {
        //cache d pagina inicial
        await db.execute('''
          CREATE TABLE grupos (
            id TEXT PRIMARY KEY,
            nome TEXT NOT NULL,
            tipo TEXT NOT NULL,
            localizacao TEXT,
            papel TEXT NOT NULL,
            nItens INTEGER NOT NULL DEFAULT 0,
            nBaixos INTEGER NOT NULL DEFAULT 0,
            nMembros INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Cache dos itens PRIMARY KEY (grupoId, codigo) pq um codigo pode estar em mais de um grupo
        await db.execute('''
          CREATE TABLE itens (
            grupoId TEXT NOT NULL,
            codigo TEXT NOT NULL,
            nome TEXT NOT NULL,
            quantidade INTEGER NOT NULL,
            quantidadeMinima INTEGER,
            atualizadoEm INTEGER NOT NULL,
            atualizadoPor TEXT NOT NULL,
            PRIMARY KEY (grupoId, codigo)
          )
        ''');

        // Fila de operações por sincronizar processada por ordem de id
        await db.execute('''
          CREATE TABLE operacoes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,      -- 'delta', 'criar', 'editar', 'remover'
            grupoId TEXT NOT NULL,
            codigo TEXT NOT NULL,
            dados TEXT,              -- detalhes da operação em JSON
            criadoEm INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  //apaga tudo, pq se outro utilizadot iniciar sessão fica com dados do anterior
  static Future<void> limpar() async {
    final base = await db;
    await base.delete('grupos');
    await base.delete('itens');
    await base.delete('operacoes');
  }  
}
