class Validator {
  static String? validateName({required String? name}) {
    if (name == null) {
     return null;
    }

    if (name.trim().isEmpty) {
     return 'Obrigatório';
    }
    
    return null;
  }

  static String? validateEmail({required String? email}) {
    if (email == null) {
      return null;
    }
    RegExp emailRegExp = RegExp( r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
   
    if (email.trim().isEmpty) {
      return 'Obrigatório';
    }

    else if (!emailRegExp.hasMatch(email.trim())) {
      return 'Introduza um email válido';
    }

    return null;
  }

  static String? validatePassword({required String? password}) {
    if (password == null) {
      return null;
    }

    if (password.isEmpty) {
      return 'Obrigatório';
    }

    else if (password.length < 8) {
      return 'Mínimo de 8 caracteres';
    }

    return null;
  }

  static String? validateConfirmarPassword({required String? password, required String? confirmarPassword}) {
    if (confirmarPassword == null) {
      return null;
    }

    if (confirmarPassword.isEmpty) {
      return 'Obrigatório';
    }

    else if(confirmarPassword != password){
      return 'As palavras-passe não coincidem';
    }

    return null;
  }

}