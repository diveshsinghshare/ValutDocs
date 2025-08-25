import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('vaultBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PinScreen(),
    );
  }
}

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  bool _showPasswordHint = true;

  void _checkPin() async {
    _showPasswordHint = false; // Hide after first dismiss

    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('pin') ?? '1234';

    if (_pinController.text == storedPin) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VaultHome()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong PIN")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter PIN",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 8),
              // ✅ Show hint only once
              if (_showPasswordHint)
                const Text(
                  "Default PIN is 1234. You can change it later from the Settings button inside the app.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueAccent,
                    height: 1.4,
                  ),
                ),

              SizedBox(height: 20),

              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _checkPin, child: const Text("Unlock")),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultHome extends StatefulWidget {
  const VaultHome({super.key});

  @override
  State<VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<VaultHome> {
  final _vaultBox = Hive.box('vaultBox');
  List<String> _lockedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    final stored = _vaultBox.get('lockedFiles');
    if (stored != null && stored is List) {
      setState(() => _lockedFiles = List<String>.from(stored));
    }
  }

  void _saveFiles() => _vaultBox.put('lockedFiles', _lockedFiles);

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!mounted) return;

        setState(() {
          _lockedFiles.add(filePath);
        });

        _saveFiles();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error importing file: $e")),
      );
    }
  }

  void _deleteFile(String path) {
    setState(() {
      _lockedFiles.remove(path);
      _saveFiles();
    });
  }

  void _openFile(String path) {
    OpenFile.open(path);
  }

  Icon _getIcon(String path) {
    if (path.endsWith(".jpg") || path.endsWith(".png")) {
      return const Icon(Icons.image, color: Colors.white);
    }
    if (path.endsWith(".mp4") || path.endsWith(".mov")) {
      return const Icon(Icons.videocam, color: Colors.white);
    }
    if (path.endsWith(".mp3") ||
        path.endsWith(".wav") ||
        path.endsWith(".m4a") ||
        path.endsWith(".aac")) {
      return const Icon(Icons.audiotrack, color: Colors.white);
    }
    return const Icon(Icons.insert_drive_file, color: Colors.white);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("My Vault "),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.image), text: 'Images'),
              Tab(icon: Icon(Icons.videocam), text: 'Videos'),
              Tab(icon: Icon(Icons.insert_drive_file), text: 'Docs'),
              Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D2671), Color(0xFFC33764)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TabBarView(
            children: [
              _buildList('image'),
              _buildList('video'),
              _buildList('doc'),
              _buildList('audio'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.deepPurple),
          onPressed: _importFile,
        ),
      ),
    );
  }

  Widget _buildList(String type) {
    final files = _lockedFiles.where((path) {
      if (type == 'image') {
        return path.endsWith('.jpg') || path.endsWith('.png');
      }
      if (type == 'video') {
        return path.endsWith('.mp4') || path.endsWith('.mov');
      }
      if (type == 'audio') {
        return path.endsWith('.mp3') ||
            path.endsWith('.wav') ||
            path.endsWith('.m4a') ||
            path.endsWith('.aac');
      }
      return !(path.endsWith('.jpg') ||
          path.endsWith('.png') ||
          path.endsWith('.mp4') ||
          path.endsWith('.mov') ||
          path.endsWith('.mp3') ||
          path.endsWith('.wav') ||
          path.endsWith('.m4a') ||
          path.endsWith('.aac'));
    }).toList();

    if (files.isEmpty) {
      return const Center(
          child: Text("No files yet.", style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (_, index) {
        final path = files[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: _getIcon(path),
                title: Text(path.split('/').last,
                    style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteFile(path),
                ),
                onTap: () => _openFile(path),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  Future<void> _changePin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('pin') ?? '1234';

    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (oldPin != storedPin) {
      _showMessage("Old PIN is incorrect");
      return;
    }
    if (newPin.isEmpty || confirmPin.isEmpty) {
      _showMessage("PIN cannot be empty");
      return;
    }
    if (newPin != confirmPin) {
      _showMessage("New PINs do not match");
      return;
    }

    await prefs.setString('pin', newPin);
    _showMessage("PIN updated successfully");

    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _oldPinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Old PIN"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New PIN"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Confirm New PIN"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePin,
              child: const Text("Change PIN"),
            ),
          ],
        ),
      ),
    );
  }
}
