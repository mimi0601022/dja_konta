# Dja Konta?

**Inventário partilhado, sempre contado.**

App Android para gerir em equipa o stock de uma loja ou o equipamento de uma sala. Aponta a câmara ao código de barras, o produto aparece e atualizas a quantidade com um toque. Funciona mesmo sem rede.

*"Dja konta?" é crioulo cabo-verdiano para "Já contaste?"*

<p align="center">
  <img src="docs/demo.gif" alt="Demonstração do scanner e das ações rápidas" width="280">
</p>

## Funcionalidades

- **Scanner** de códigos de barras e QR, com introdução manual se a câmara falhar
- **Ações rápidas** de +1 e −1 numa folha que abre logo depois do scan
- **Aviso de stock baixo** quando a quantidade fica abaixo do mínimo
- **Grupos partilhados** com papéis: staff edita, viewer só consulta
- **Convites** por código de 7 dias ou por QR
- **Modo offline**: as alterações ficam numa fila local e sincronizam quando a rede volta

## Como funciona o modo offline

A app guarda os grupos e os produtos numa cache em SQLite. Cada alteração feita sem rede entra numa fila de operações, também em SQLite.

Quando a ligação volta, detetada através do `.info/connected` do Firebase, um serviço de sincronização processa a fila pela ordem em que as alterações foram feitas:

- **+1 e −1** são enviados como incrementos e não como valores finais, por isso duas pessoas a mexer no mesmo produto ao mesmo tempo não se apagam uma à outra
- **criar e editar** verificam primeiro se o produto ainda existe no servidor

Antes de sair da conta, a app avisa se ainda há alterações por sincronizar.

## Tecnologias

| Camada | Tecnologia |
|---|---|
| App | Flutter, Dart |
| Autenticação | Firebase Authentication (email e password, com verificação de email) |
| Base de dados | Firebase Realtime Database, com regras de segurança por papel |
| Armazenamento local | SQLite (sqflite) |
| Scanner | Câmara do dispositivo |

## Correr localmente

Precisas do [Flutter](https://docs.flutter.dev/get-started/install) instalado e de um projeto Firebase teu.

```bash
git clone https://github.com/mimi0601022/dja_konta.git
cd dja_konta
flutter pub get
flutterfire configure
flutter run
```

## Contexto

Projeto desenvolvido na unidade curricular de Computação Móvel do Mestrado em Informática da ESTGD, Politécnico de Portalegre.

## Autora

**Miriam Pina** · [Portfólio](https://miriampina.vercel.app/) · [LinkedIn](https://linkedin.com/in/miriiampina)
