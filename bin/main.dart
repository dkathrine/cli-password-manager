// imports
import 'dart:io';
import 'encryption_service.dart';
import 'vault_manager.dart';

Future<void> main() async {
  // Initialize the encryption service and vault manager
  final encryptionService = EncryptionService();
  final vaultManager = VaultManager(encryptionService);
  print('Welcome to the Password Manager!');

  // Check if the vault file exists in the home directory
  // If it exists, load the vault; otherwise, create a new vault
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final file = File('$homeDir/vault.json');
  if (await file.exists()) {
    print('🔍 Vault file found. Loading existing vault...');
    await vaultManager.loadVault();
  } else {
    print('❗ Vault file not found. A new vault will be created.');
  }

  // Prompt the user for the master password
  print('Please enter your master password:');
  final masterPassword = stdin.readLineSync().toString() ?? '';
  // If the master password is empty, exit the program
  if (masterPassword.isEmpty) {
    print('❌ Master password cannot be empty.');
    return;
  }
  // Login to the vault manager with the master password
  await vaultManager.login(masterPassword);
  // Display the main menu
  await vaultManager.menu();
}
