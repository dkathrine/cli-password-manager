// imports
import 'dart:io';
import 'encryption_service.dart';
import 'vault_manager.dart';

Future<void> main() async {
  // Initialize the encryption service and vault manager
  final encryptionService = EncryptionService();
  final vaultManager = VaultManager(encryptionService);

  // bool variable called exit, default value is false
  bool shouldExit = false;
  // as long as exit is false the program will run
  while (!shouldExit) {
    print('\x1B[1;35mWelcome to the CLI Password Manager!\x1B[0m');

    // Prompt the user to Register or Login
    print('\x1B[32m1. ✍️  Register\n\x1B[34m2. 🚪 Login\x1B[0m');
    final option = stdin.readLineSync();

    // Prompt the user for a username
    print('Please enter your username:');
    final username = stdin.readLineSync() ?? '';
    // if the username is empty, exit the program
    if (username.isEmpty) {
      print('❌ \x1B[31mUsername cannot be empty.\x1B[0m');
      return;
    }

    // Prompt the user for the master password
    print('Please enter your master password:');
    final masterPassword = stdin.readLineSync() /* .toString() */ ?? '';
    // If the master password is empty, exit the program
    if (masterPassword.isEmpty) {
      print('❌ \x1B[31mMaster password cannot be empty.\x1B[0m');
      return;
    }

    bool success = false;

    switch (option) {
      case '1':
        success = await vaultManager.register(username, masterPassword);
        break;
      case '2':
        success = await vaultManager.login(username, masterPassword);
        break;
      default:
        print('❌ \x1B[31mInvalid option selected.\x1B[0m');
    }

    // Display the main menu if register/login was successful
    if (success) {
      shouldExit = await vaultManager.menu();
    }
  }

  if (shouldExit) {
    exit(0);
  }
}
