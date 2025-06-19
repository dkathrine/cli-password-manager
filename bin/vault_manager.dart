import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'encryption_service.dart';

class VaultManager {
  /* declaring our EncryptionService as encryptService */
  final EncryptionService encryptService;
  /* initializing a empty Map to store our passwords in */
  final Map<String, Map<String, String>> _vault = {};
  SecretKey? _masterKey;
  Uint8List?
  _salt; // AI: figured out with the help of AI that I need to store the salt as well
  /* 
    Constructor for VaultManager that takes an instance of EncryptionService.
    This allows us to use the encryption and decryption methods defined in EncryptionService.
  */
  VaultManager(this.encryptService);
  /*
    function to "login" to the vault by providing a master password.
    It derives a master key from the password + salt.
  */
  Future<void> login(String masterPassword) async {
    // Check if the master key is already set if not, generate a new salt and derive the master key
    _salt ??= encryptService
        .generateSalt(); //AI: figured out with the help of AI that I need to only generate a new salt if its not already set
    _masterKey = await encryptService.deriveKey(
      masterPassword,
      _salt!,
    ); // Derive the master key from the password and salt
    if (_masterKey != null) {
      print('🔓 Logged in successfully. Master Key derived.');
    } // If the master key is successfully derived, we print a success message
  }

  /* 
    This function encrypts and adds a new password to the vault.
    It requires a name, username, and password.
  */
  Future<void> addPassword(
    String name,
    String username,
    String password,
  ) async {
    //only execute this function if the master key exists
    if (_masterKey == null) {
      print('❌ Please login first.');
      return;
    }
    // encrypt the password using the master key
    final encrypted = await encryptService.encryptPassword(
      password,
      _masterKey!,
    );

    // Store the encrypted password in the vault with the provided name and username as well as the encrypted nonce and MAC
    _vault[name] = {
      'username': username,
      'cipherText': encrypted['cipherText'],
      'nonce': encrypted['nonce'],
      'mac':
          encrypted['mac'], //AI: figured out with the help of AI that I needed to store the MAC as well
    };

    print('✅ Password for $name added successfully.');
  }

  /* 
    This function retrieves a password from the vault by its name.
    It decrypts the password using the master key.
  */
  Future<void> showPassword(String name) async {
    //throw error if master key is not set
    if (_masterKey == null) {
      print('❌ Please login first.');
      return;
    }
    // check if the name exists in the vault
    final entry = _vault[name];
    if (entry == null) {
      print('❌ No entry found for $name.');
      return;
    }
    // decode the base64 strings to get the encrypted data
    /* final cipherText = base64Decode(entry['cipherText']!);
    final nonce = base64Decode(entry['nonce']!); */
    try {
      // decrypt the password using the master key
      final decrypted = await encryptService.decryptPassword(
        entry,
        _masterKey!,
      );
      // print the decrypted password along with the username
      print('🔐 Entry: $name');
      print('👤 Username: ${entry['username']}');
      print('🔑 Password: $decrypted');
    } catch (e) {
      // handle decryption errors
      print('❌ Error decrypting password for $name: $e');
    }
  }

  /* 
    This function lists all the entries in the vault.
    It prints the names of all stored passwords.
  */
  void listPasswords() {
    //prints out that there are no passwords stored if the vault is empty
    if (_vault.isEmpty) {
      print('❌ No passwords stored in the vault.');
      return;
    }
    // prints out all the names of the stored passwords
    print('📜 Stored Passwords:');
    _vault.forEach((name, i) {
      print('-🔑 $name');
    });
  }

  /*
    This function removes a password from the vault by its name.
    It checks if the name exists and removes it if found.
  */
  Future<void> removePassword(String name) async {
    //throw error if masterKey is not set
    if (_masterKey == null) {
      print('❌ Please login first.');
      return;
    }
    // check if the name exists in the vault
    if (_vault.containsKey(name)) {
      // remove the entry from the vault
      _vault.remove(name);
      print('✅ Password for $name removed successfully.');
    } else {
      print('❌ No entry found for $name.');
    }
  }

  /*
    This function stores the vault to a JSON file.
    First safe the home directory to a variable called homeDir.
  */
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  Future<void> saveVault() async {
    /* Check if the master key is set before saving
    If not, prompt the user to login first */
    if (_masterKey == null) {
      print('❌ Please login first.');
      return;
    }

    /* 
      Create file if it does not exist.
      The file will be created in the home directory with the name vault.json.
    */
    final file = File('$homeDir/vault.json');

    final vaultData = {'salt': base64.encode(_salt!), 'vault': _vault};

    /*
      Convert the vault data to JSON format 
      Save the JSON data to the file.
      If the file is saved successfully, print a success message.
      If there is an error while saving, catch the error and print an error message.
    */
    final jsonData = jsonEncode(vaultData);
    await file
        .writeAsString(jsonData)
        .then((_) {
          print('✅ Vault saved successfully to vault.json');
        })
        .catchError((e) {
          print('❌ Error saving vault: $e');
        });
  }

  /*
    This function loads the vault from a JSON file.
  */
  Future<void> loadVault() async {
    // load the vault from the file vault.json if it exists
    final file = File('$homeDir/vault.json');
    if (await file.exists()) {
      final jsonData = await file.readAsString();
      final Map<String, dynamic> loadedData = jsonDecode(jsonData);

      // Decode the salt from base64 and load the vault data
      _salt = base64.decode(loadedData['salt']);
      final Map<String, dynamic> loadedVault = loadedData['vault'];

      // Clear the current vault
      _vault.clear();

      // Populate the vault with the loaded data
      loadedVault.forEach((name, entry) {
        _vault[name] = {
          'username': entry['username'],
          'cipherText': entry['cipherText'],
          'nonce': entry['nonce'],
          'mac': entry['mac'],
        };
      });
      // print a success message if the vault is loaded successfully
      print('✅ Vault loaded successfully from vault.json');
    } else {
      // print an error message if the vault file does not exist
      print('❌ Vault file not found.');
    }
  }

  Future<void> menu() async {
    // Display the vault manager menu and handle user input
    while (true) {
      // Print the menu options
      print('\n🔐 Password Manager Menu:');
      print('1. Add Password');
      print('2. Show Password');
      print('3. List Passwords');
      print('4. Remove Password');
      print('5. Save Vault');
      print('6. Load Vault');
      print('7. Exit');
      // Prompt the user to choose an option
      print('Please choose an option:');
      final choice = stdin.readLineSync();
      // Handle the user's choice
      switch (choice) {
        case '1':
          print('Enter name:');
          final name = stdin.readLineSync() ?? '';
          print('Enter username:');
          final username = stdin.readLineSync() ?? '';
          print('Enter password:');
          final password = stdin.readLineSync() ?? '';
          // Call the addPassword function with the provided inputs
          await addPassword(
            name.toString(),
            username.toString(),
            password.toString(),
          );
          break;
        case '2':
          print('Enter name to show password:');
          // Prompt the user for the name of the password to show
          // Call the showPassword function with the provided name
          final showName = stdin.readLineSync() ?? '';
          await showPassword(showName.toString());
          break;
        case '3':
          // Call the listPasswords function to display all stored passwords
          listPasswords();
          break;
        case '4':
          print('Enter name to remove password:');
          // Prompt the user for the name of the password to remove
          // Call the removePassword function with the provided name
          final removeName = stdin.readLineSync() ?? '';
          await removePassword(removeName.toString());
          break;
        case '5':
          // Call the saveVault function to save the current vault state
          await saveVault();
          break;
        case '6':
          // Call the loadVault function to load the vault from the file
          await loadVault();
          break;
        case '7':
          // Call the saveVault function to save the vault before exiting
          await saveVault();
          print('Exiting...');
          return;
        default:
          // Handle invalid choices
          print('❌ Invalid choice. Please try again.');
      }
    }
  }
}
