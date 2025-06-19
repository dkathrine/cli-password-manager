import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'encryption_service.dart';

class VaultManager {
  /* declaring our EncryptionService as encryptService */
  final EncryptionService encryptService;
  /* initializing a empty Map to store our passwords in */
  final Map<String, Map<String, String>> _vault = {};
  SecretKey? _masterKey;
  String? _username;
  // AI: figured out with the help of AI that I should store the salt as well
  /* Uint8List? _salt; */
  /* 
    Constructor for VaultManager that takes an instance of EncryptionService.
    This allows us to use the encryption and decryption methods defined in EncryptionService.
  */
  VaultManager(this.encryptService);
  /* 
    We save the home directory to a variable called homeDir. 
  */
  final homeDir =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  /* Functions to get the vault and salt files. */
  File _getVaultFile(String username) {
    return File('$homeDir/vaults/$username/${username}_vault.json');
  }

  /* 
    We store the Salt inside a .bin(binary-file) to avoid potential tampering with the file. 
    Making the file more secure.
  */
  File _getSaltFile(String username) {
    return File('$homeDir/vaults/$username/${username}_vault.bin');
  }

  /*
    function to "register" a new user by providing a username and master password.
    It creates a salt file and a vault file for the user.
    The salt file is used to derive the master key from the master password.
    The vault file is used to store the user's passwords.
    If the user already exists, it will not create a new vault.
  */
  Future<bool> register(String username, String masterPassword) async {
    // saving the directories for vault & salt in corresponding variables
    final saltFile = _getSaltFile(username);
    final vaultFile = _getVaultFile(username);

    // check if the files already exist and if they do tell the user to login instead
    if (await saltFile.exists() || await vaultFile.exists()) {
      print(
        '❌ \x1B[31mUser $username already exists. Please try logging in instead\x1B[0m',
      );
      return false;
    }

    // generate a salt and create a folder and the corresponding salt file in it
    final salt = encryptService.generateSalt();
    await saltFile.create(recursive: true);
    await saltFile.writeAsBytes(salt);

    // derive and store a master key from the password and salt
    _masterKey = await encryptService.deriveKey(masterPassword, salt);
    //store the username in the _username variable
    _username = username;

    /*
      Clear the current vault in case any data is currently loaded inside it
      then create a folder(if it didn't already happen) and the corresponding vault file in it
    */
    _vault.clear();
    await vaultFile.create(
      recursive: true,
    ); // recursive: true automatically created the folder if it's missing
    await vaultFile.writeAsString(jsonEncode(_vault));

    /*
      tell the user that he registered successfully and log them in.
    */
    print('✅ \x1B[32mUser $username registered successfully.\x1B[0m');
    return true;
  }

  /* function to login to the vault by providing a username + master password. */
  Future<bool> login(String username, String masterPassword) async {
    // saving the directories for vault & salt in corresponding variables
    final saltFile = _getSaltFile(username);
    final vaultFile = _getVaultFile(username);

    // check if the files doesn't exist and if they don't tell the user to register first
    if (!await saltFile.exists() || !await vaultFile.exists()) {
      print(
        '❌ \x1B[31mUser $username does not exist. Please register first.\x1B[0m',
      );
      return false;
    }

    /*
      load the salt from the saltFile and store the value in the salt variable
      then derive a master key from it using the salt + masterpassword and storing it in the derivedKey variable
    */
    final salt = await saltFile.readAsBytes();
    final derivedKey = await encryptService.deriveKey(masterPassword, salt);
    _username = username;

    /*
      checks if the vaulFile already exists
      then read and store the vaultFile in the vaultData variable
    */
    if (await vaultFile.exists()) {
      final vaultData = await vaultFile.readAsString();
      // decode the vaultData and store it in loadedVault variable
      final loadedVault = jsonDecode(vaultData);
      // clear the vault in case any data is inside it
      _vault.clear();
      // populate the _vault Map with the Data stored in loadedVault
      loadedVault.forEach((name, entry) {
        _vault[name] = {
          'username': entry['username'],
          'cipherText': entry['cipherText'],
          'nonce': entry['nonce'],
          'mac': entry['mac'],
        };
      });

      //tell the user the vault loaded successfully
      print('✅ \x1B[32mVault loaded successfully for user $username.\x1B[0m');
    } else {
      //in case the file doesn't exist tell the user that it doesn't exist
      print('❌ \x1B[31mVault file for user $username does not exist.\x1B[0m');
    }

    // check if one of the values stored in our _vault can be decrypted given the password used to login
    try {
      for (final entry in _vault.values) {
        await encryptService.decryptPassword(entry, derivedKey);
        break;
      }
    } catch (e) {
      //if a error is catched the password was incorrect and tell the user that the password is incorrect
      print('❌ \x1B[31mIncorrect password.\x1B[0m');
      return false;
    }
    // store the master key saved in derivedKey inside _masterKey to make it accessible to the functions
    _masterKey = derivedKey;
    // tell the user they successfully logged in
    print('✅ \x1B[32mLogged in as $username.\x1B[0m');
    return true;
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
      print('❌ \x1B[31mPlease login first.\x1B[0m');
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
      //AI: figured out with the help of AI that I needed to store the MAC as well
      'mac': encrypted['mac'],
    };

    print('✅ \x1B[32mPassword for $name added successfully.\x1B[0m');
  }

  /* 
    This function retrieves a password from the vault by its name.
    It decrypts the password using the master key.
  */
  Future<void> showPassword(String name) async {
    //throw error if master key is not set
    if (_masterKey == null) {
      print('❌ \x1B[31mPlease login first.\x1B[0m');
      return;
    }
    // check if the name exists in the vault
    final entry = _vault[name];
    if (entry == null) {
      print('❌ \x1B[31mNo entry found for $name.\x1B[0m');
      return;
    }

    try {
      // decrypt the password using the master key
      final decrypted = await encryptService.decryptPassword(
        entry,
        _masterKey!,
      );
      // print the decrypted password along with the username
      print('🔐 \x1B[33mEntry: $name');
      print('👤 Username: ${entry['username']}');
      print('🔑 Password: $decrypted\x1B[0m');
    } catch (e) {
      // handle decryption errors
      print('❌ \x1B[31mError decrypting password for $name: $e\x1B[0m');
    }
  }

  /* 
    This function lists all the entries in the vault.
    It prints the names of all stored passwords.
  */
  void listPasswords() {
    //prints out that there are no passwords stored if the vault is empty
    if (_vault.isEmpty) {
      print('❌ \x1B[31mNo passwords stored in the vault.\x1B[0m');
      return;
    }
    // prints out all the names of the stored passwords
    print('📜 \x1B[35mStored Passwords:\x1B[0m');
    _vault.forEach((name, i) {
      print('\x1B[36m🔑 $name\x1B[0m');
    });
  }

  /*
    This function removes a password from the vault by its name.
    It checks if the name exists and removes it if found.
  */
  Future<void> removePassword(String name) async {
    //throw error if masterKey is not set
    if (_masterKey == null) {
      print('❌ \x1B[31mPlease login first.\x1B[0m');
      return;
    }
    // check if the name exists in the vault
    if (_vault.containsKey(name)) {
      // remove the entry from the vault
      _vault.remove(name);
      print('✅ \x1B[32mPassword for $name removed successfully.\x1B[0m');
    } else {
      print('❌ \x1B[31mNo entry found for $name.\x1B[0m');
    }
  }

  /*
    This function stores the vault to a JSON file.
  */

  Future<void> saveVault() async {
    /* Check if the master key is set before saving
    If not, prompt the user to login first */
    if (_masterKey == null) {
      print('❌ \x1B[31mPlease login first.\x1B[0m');
      return;
    }

    /* 
      Create file if it does not exist.
      The file will be created in the vault folder inside the home directory with the name vault.json.
    */
    final file = _getVaultFile(_username!);

    /* final vaultData = {'salt': base64.encode(_salt!), 'vault': _vault}; */

    /*
      Convert the vault data to JSON format 
      Save the JSON data to the file.
      If the file is saved successfully, print a success message.
      If there is an error while saving, catch the error and print an error message.
    */
    final jsonData = jsonEncode(_vault);
    await file
        .writeAsString(jsonData)
        .then((_) {
          print('✅ \x1B[32mVault saved successfully to vault.json\x1B[0m');
        })
        .catchError((e) {
          print('❌ \x1B[31mError saving vault: $e\x1B[0m');
        });
  }

  /*
    This function loads the vault from a JSON file.
  */
  Future<void> loadVault() async {
    if (_masterKey == null) {
      print('❌ \x1B[31mPlease login first.\x1B[0m');
      return;
    }
    // load the vault from the file vault.json if it exists
    final file = _getVaultFile(_username!);
    if (await file.exists()) {
      final jsonData = await file.readAsString();
      final Map<String, dynamic> loadedVault = jsonDecode(jsonData);

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
      print('✅ \x1B[32mVault loaded successfully for user $_username.\x1B[0m');
    } else {
      // print an error message if the vault file does not exist
      print('❌ \x1B[31mVault file not found.\x1B[0m');
    }
  }

  Future<bool> menu() async {
    // Display the vault manager menu and handle user input
    while (true) {
      // Print the menu options
      print('\n🔐 \x1B[1;35mPassword Manager Menu:\x1B[0m');
      print('\x1B[34m1. ➕ Add Password');
      print('2. 👁  Show Password');
      print('3. 📜 List Passwords');
      print('4. ➖ Remove Password');
      print('5. 🔏 Save Vault');
      print('6. 🔄 Load Vault');
      print('7. ❌ Exit\x1B[0m');
      // Prompt the user to choose an option
      print('Please choose an option:');
      final choice = stdin.readLineSync();
      // Handle the user's choice
      switch (choice) {
        case '1':
          print('Enter name:');
          final name = stdin.readLineSync() ?? '';
          print('Enter username/email:');
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
          print('\x1B[31mExiting...\x1B[0m');
          //return true to set the exit value inside main.dart to true stopping the programm
          return true;
        default:
          // Handle invalid choices
          print('❌ \x1B[31mInvalid choice. Please try again.\x1B[0m');
      }
    }
  }
}
