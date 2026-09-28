import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobil_proje/utils/emulator.dart';
import 'package:mobil_proje/utils/firebase_options.dart';
import 'package:mobil_proje/utils/background.dart';

class AddTechnicianScreen extends StatefulWidget {
  const AddTechnicianScreen({super.key});

  @override
  State<AddTechnicianScreen> createState() => _AddTechnicianScreenState();
}

class _AddTechnicianScreenState extends State<AddTechnicianScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  XFile? pickedImage;
  String? photoUrl;

  Future<FirebaseAuth> _getSecondaryAuth() async {
    const secondaryAppName = "adminHelper";
    FirebaseApp secondaryApp;

    try {
      secondaryApp = Firebase.app(secondaryAppName);
    } on FirebaseException {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await connectAuthToEmulator(FirebaseAuth.instanceFor(app: secondaryApp));
    }

    return FirebaseAuth.instanceFor(app: secondaryApp);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    PermissionStatus status = PermissionStatus.granted;

    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      if (android.version.sdkInt < 33) {
        status = await Permission.storage.request();
      }
    }

    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Galeri izni verilmedi!")));
      return;
    }

    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() => pickedImage = img);
    }
  }

  Future<void> _saveTechnician() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final adminAuth = await _getSecondaryAuth();
      final UserCredential cred = await adminAuth
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final String uid = cred.user!.uid;

      await cred.user!.sendEmailVerification();
      await adminAuth.signOut();

      if (pickedImage != null) {
        final ref = FirebaseStorage.instance.ref("technicians/$uid.jpg");

        await ref.putFile(File(pickedImage!.path));
        photoUrl = await ref.getDownloadURL();
      } else {
        photoUrl = null;
      }

      await FirebaseFirestore.instance.collection("technicians").doc(uid).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
        "photoUrl": photoUrl ?? "",
        "rating": 0.0,
        "ratingCount": 0,
        "totalStars": 0,
        "active": true,
        "location": null,
        "isAvailable": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Teknisyen basariyla eklendi!")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Yeni Teknisyen Kaydı"),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text(
                          "Yeni Teknisyen Kaydı",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 55,
                            backgroundImage: pickedImage != null
                                ? FileImage(File(pickedImage!.path))
                                : null,
                            child: pickedImage == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: "İsim",
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Boş bırakılamaz" : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: "E-posta",
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v == null || !v.contains("@")
                              ? "Geçerli email gir"
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Telefon",
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v == null || v.length < 10
                              ? "Geçerli telefon gir"
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Şifre",
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 6
                              ? null
                              : "Şifre en az 6 karakter olmalı",
                        ),

                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _saveTechnician,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Kaydet",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
