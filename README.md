# Dja Konta?

Aplicação móvel para gerir inventários partilhados. O utilizador lê o código de barras de um produto com a câmara e vê ou altera a quantidade. As alterações chegam aos outros membros em tempo real e podem ser feitas sem rede.

O nome vem do crioulo cabo-verdiano: *Dja konta?* significa "Já contaste?".

Projeto da unidade curricular de Computação Móvel (Mestrado em Informática, ESTGD, Politécnico de Portalegre), opção D: Inventário Simples com Scanner.

## Funcionalidades

- Registo e login com email e palavra-passe, com verificação do email.
- Vários inventários (grupos) por utilizador, do tipo stock ou sala.
- Dois papéis por grupo: **staff**, que altera os itens e gere os membros, e **viewer**, que apenas consulta.
- Convites com código de seis caracteres, válidos durante sete dias, que podem ser escritos, lidos por QR ou partilhados.
- Leitura de códigos de barras e QR, com uma folha inferior de ações rápidas (+1, −1 e editar).
- Lista de itens em tempo real, com pesquisa e aviso de stock baixo.
- **Modo offline:** as alterações ficam numa fila em SQLite e são enviadas quando a ligação volta. As quantidades são enviadas como incrementos, para que as alterações de vários dispositivos se somem.

## Tecnologias

- Flutter (Dart)
- Firebase Authentication
- Firebase Realtime Database, com regras de segurança
- sqflite (SQLite local)
- mobile_scanner, qr_flutter e share_plus

## Estrutura do código

```
lib/
  models/     classes dos dados (Grupo, Item, Membro, Convite)
  services/   lógica e acesso aos dados (autenticação, grupos, membros, itens, ligação, sincronização)
  screens/    ecrãs completos
  widgets/    componentes reutilizados (folha do item, folha do membro, faixa de sincronização)
  data/       base de dados SQLite
  utils/      validação de formulários e formatação de datas
```

## Como correr

Os ficheiros de configuração do Firebase não estão no repositório. Para correr a aplicação é preciso ter um projeto Firebase próprio.

1. Instalar o Flutter e a FlutterFire CLI.
2. Criar um projeto no Firebase e ativar o **Authentication** (email/palavra-passe) e o **Realtime Database**.
3. Na pasta do projeto, gerar a configuração:
   ```
   flutterfire configure
   ```
4. Publicar as regras do ficheiro `database.rules.json` no Realtime Database.
5. Instalar as dependências e correr:
   ```
   flutter pub get
   flutter run
   ```

## Autora

Miriam Pina, 2026
