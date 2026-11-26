import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

//diz se há ligação, p faixa sem ligação e sincronizaçao
class ConexaoService {
  // Começa em true para não piscar "Sem ligação" ao abrir a app
  static final online = ValueNotifier<bool>(true);

  static bool _iniciado = false;
  static Timer? _timerQueda;

  static void iniciar(){
    if(_iniciado) return; //ta liga so um bes

    _iniciado = true;

    //'.info/connected' é um caminho do firebase
    //true enquanto app sta ligado ao servidor
    FirebaseDatabase.instance.ref('.info/connected').onValue.listen((evento){
      final ligado = evento.snapshot.value == true;

      if (ligado) {
        //voltou a ligaçao
        _timerQueda?.cancel();
        online.value = true;
      }else {
        //sem ligação, espera 2 segundos antes de avisar p n piscar ao iniciar 
        _timerQueda?.cancel();
        _timerQueda = Timer(const Duration(seconds: 2), (){
          online.value = false;
        });
      }
    });
  }
}