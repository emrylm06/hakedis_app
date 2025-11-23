// 1.1 Firebase Konfigürasyonu ******************************************************************
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCG4g4HYU89tG_wjgvH8uJ1Z00fSlRrYPI",
      authDomain: "hakedis-can.firebaseapp.com",
      projectId: "hakedis-can",
      storageBucket: "hakedis-can.firebasestorage.app",
      messagingSenderId: "626879438556",
      appId: "1:626879438556:web:bbd8c84c4fc78dd8571e19",
    ),
  );
  runApp(MyApp());
}
// 1.1 Firebase Konfigürasyonu SONU ******************************************************************

// 1.2 Provider Kurulumu ******************************************************************
// Provider kurulumu MyApp sınıfı içinde MultiProvider ile yapılmaktadır
// Bu bölüm MyApp sınıfının provider kısmını içerir
// 1.2 Provider Kurulumu SONU ******************************************************************

// 1.3 Ana Widget Yapısı ******************************************************************
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (context) {
          final dataProvider = DataProvider();
          // Provider oluşturulduğunda verileri yükle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            dataProvider.loadAllData();
          });
          return dataProvider;
        }),
      ],
      child: MaterialApp(
        title: 'Hakediş Takip App',
        theme: ThemeData(
          primarySwatch: Colors.amber,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: PasswordScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
// 1.3 Ana Widget Yapısı SONU ******************************************************************

// 1. BÖLÜM SONU ******************************************************************
// 2.1 AppSettings Sınıfı ******************************************************************
class AppSettings with ChangeNotifier {
  String _adminUsername = 'admin';
  String _adminPassword = '147169';
  double _kdvOrani = 20;
  double _tevkifatOrani = 0.2;
  double _tonajBirimFiyat = 7.5;
  String _raporBasligi = 'EMRAH YILMAZER';
  List<String> _araclar = ['45', '46'];
  List<String> _giderKalemleri = ['YAKIT', 'BAKIM'];
  List<String> _personeller = ['ŞOFÖR AHMET', 'ŞOFÖR MEHMET'];
  List<String> _cariler = ['ÇAN LİNYİTLERİ', 'DEMİR MADENCİLİK'];
  DateTime? _sonStartDate;
  DateTime? _sonEndDate;
  String _sonAracFiltresi = 'Tümü';
  bool _tevkifatUygulansin = true;
  Map<String, Map<String, dynamic>> _kullanicilar = {};
  String _currentUser = '';
  bool _isAdmin = false;
  String _selectedUserForAdmin = '';

  String get adminUsername => _adminUsername;
  String get adminPassword => _adminPassword;
  double get kdvOrani => _kdvOrani;
  double get tevkifatOrani => _tevkifatOrani;
  double get tonajBirimFiyat => _tonajBirimFiyat;
  String get raporBasligi => _raporBasligi;
  List<String> get araclar => _araclar;
  List<String> get giderKalemleri => _giderKalemleri;
  List<String> get personeller => _personeller;
  List<String> get cariler => _cariler;
  DateTime? get sonStartDate => _sonStartDate;
  DateTime? get sonEndDate => _sonEndDate;
  String get sonAracFiltresi => _sonAracFiltresi;
  bool get tevkifatUygulansin => _tevkifatUygulansin;
  Map<String, Map<String, dynamic>> get kullanicilar => _kullanicilar;
  String get currentUser => _currentUser;
  bool get isAdmin => _isAdmin;
  String get selectedUserForAdmin => _selectedUserForAdmin;

  AppSettings() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _sonStartDate = prefs.getString('sonStartDate') != null
        ? DateTime.parse(prefs.getString('sonStartDate')!)
        : null;
    _sonEndDate = prefs.getString('sonEndDate') != null
        ? DateTime.parse(prefs.getString('sonEndDate')!)
        : null;
    _sonAracFiltresi = prefs.getString('sonAracFiltresi') ?? 'Tümü';
    _currentUser = prefs.getString('currentUser') ?? '';

    // DEBUG: SharedPreferences'tan okunan isAdmin değerini kontrol et
    // ÖNEMLİ DÜZELTME: isAdmin değerini doğru şekilde yükle
    final savedIsAdmin = prefs.getBool('isAdmin');
    print('🔍 _loadSettings - SharedPreferences isAdmin: $savedIsAdmin');
// Eğer currentUser 'admin' ise, otomatik olarak admin yap
    _isAdmin = savedIsAdmin ?? (_currentUser == 'admin');
    print('🔍 _loadSettings - Sonuç isAdmin: $_isAdmin');

    _selectedUserForAdmin = prefs.getString('selectedUserForAdmin') ?? '';

    final kullaniciString = prefs.getString('kullanıcılar');
    if (kullaniciString != null) {
      final decoded = json.decode(kullaniciString);
      _kullanicilar = Map<String, Map<String, dynamic>>.from(decoded.map(
              (key, value) => MapEntry(key, Map<String, dynamic>.from(value))
      ));
    }

    // DEBUG: Yüklenen değerleri yazdır
    print('📥 _loadSettings SONUÇ:');
    print('  - _currentUser: $_currentUser');
    print('  - _isAdmin: $_isAdmin');
    print('  - _selectedUserForAdmin: $_selectedUserForAdmin');

    // Kullanıcı ayarlarını yükle
    if (_currentUser.isNotEmpty) {
      await _loadUserSettings();
    }

    notifyListeners();
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userSettingsKey = 'userSettings_$_currentUser';
    final userSettingsString = prefs.getString(userSettingsKey);

    if (userSettingsString != null) {
      final userSettings = json.decode(userSettingsString);
      _kdvOrani = userSettings['kdvOrani'] ?? _kdvOrani;
      _tevkifatOrani = userSettings['tevkifatOrani'] ?? _tevkifatOrani;
      _tonajBirimFiyat = userSettings['tonajBirimFiyat'] ?? _tonajBirimFiyat;
      _raporBasligi = userSettings['raporBasligi'] ?? _raporBasligi;
      _tevkifatUygulansin = userSettings['tevkifatUygulansin'] ?? _tevkifatUygulansin;
      _araclar = List<String>.from(userSettings['araclar'] ?? _araclar);
      _giderKalemleri = List<String>.from(userSettings['giderKalemleri'] ?? _giderKalemleri);
      _personeller = List<String>.from(userSettings['personeller'] ?? _personeller);
      _cariler = List<String>.from(userSettings['cariler'] ?? _cariler);
    }
  }

  Future<void> _saveUserSettings() async {
    if (_currentUser.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final userSettingsKey = 'userSettings_$_currentUser';
    final userSettings = {
      'kdvOrani': _kdvOrani,
      'tevkifatOrani': _tevkifatOrani,
      'tonajBirimFiyat': _tonajBirimFiyat,
      'raporBasligi': _raporBasligi,
      'tevkifatUygulansin': _tevkifatUygulansin,
      'araclar': _araclar,
      'giderKalemleri': _giderKalemleri,
      'personeller': _personeller,
      'cariler': _cariler,
    };
    await prefs.setString(userSettingsKey, json.encode(userSettings));
  }

  Future<void> saveFiltreler() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sonStartDate', _sonStartDate?.toIso8601String() ?? '');
    await prefs.setString('sonEndDate', _sonEndDate?.toIso8601String() ?? '');
    await prefs.setString('sonAracFiltresi', _sonAracFiltresi);
  }

  void setFiltreler(DateTime? startDate, DateTime? endDate, String aracFiltresi) {
    _sonStartDate = startDate;
    _sonEndDate = endDate;
    _sonAracFiltresi = aracFiltresi;
    saveFiltreler();
    notifyListeners();
  }

  // DÜZELTİLMİŞ setCurrentUser metodu
  void setCurrentUser(String username, bool isAdmin) async {
    print('=== SET CURRENT USER (DÜZELTİLMİŞ) ===');

    // Memory'de tut
    _currentUser = username;
    _isAdmin = isAdmin;
    _selectedUserForAdmin = isAdmin ? '' : username;

    print('🎯 MEMORY DEĞİŞKENLERİ:');
    print('  - _currentUser: $_currentUser');
    print('  - _isAdmin: $_isAdmin');
    print('  - _selectedUserForAdmin: $_selectedUserForAdmin');

    // SHAREDPREFERENCES'A KAYDET - BU ÇOK ÖNEMLİ!
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUser', _currentUser);
    await prefs.setBool('isAdmin', _isAdmin);
    await prefs.setString('selectedUserForAdmin', _selectedUserForAdmin);

    print('💾 SharedPreferences kaydedildi:');
    print('  - currentUser: $_currentUser');
    print('  - isAdmin: $_isAdmin');
    print('  - selectedUserForAdmin: $_selectedUserForAdmin');

    // Kullanıcı ayarlarını yükle
    await _loadUserSettings();

    print('📢 NOTIFY LISTENERS ÇAĞRILIYOR');
    notifyListeners();

    print('✅ MEMORY VE SHAREDPREFERENCES GÜNCELLENDİ');
    print('=== SET CURRENT USER TAMAMLANDI ===');
  }

  void setSelectedUserForAdmin(String username) async {
    _selectedUserForAdmin = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedUserForAdmin', username);
    notifyListeners();
  }

  void addKullanici(String username, String password) {
    print('➕ Kullanıcı ekleniyor: $username');
    _kullanicilar[username] = {
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _saveKullanicilar();
    notifyListeners();
    print('✅ Kullanıcı eklendi: $username, Toplam: ${_kullanicilar.length}');
  }

  void removeKullanici(String username) {
    _kullanicilar.remove(username);
    _saveKullanicilar();
    notifyListeners();
  }

  Future<void> _saveKullanicilar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kullanıcılar', json.encode(_kullanicilar));
  }

  void updateSettings({
    double? kdvOrani,
    double? tevkifatOrani,
    double? tonajBirimFiyat,
    String? raporBasligi,
    bool? tevkifatUygulansin,
  }) {
    _kdvOrani = kdvOrani ?? _kdvOrani;
    _tevkifatOrani = tevkifatOrani ?? _tevkifatOrani;
    _tonajBirimFiyat = tonajBirimFiyat ?? _tonajBirimFiyat;
    _raporBasligi = raporBasligi ?? _raporBasligi;
    _tevkifatUygulansin = tevkifatUygulansin ?? _tevkifatUygulansin;
    _saveUserSettings();
    notifyListeners();
  }

  void addArac(String aracKodu) {
    if (!_araclar.contains(aracKodu)) {
      _araclar.add(aracKodu);
      _saveUserSettings();
      notifyListeners();
    }
  }

  void removeArac(String aracKodu) {
    _araclar.remove(aracKodu);
    _saveUserSettings();
    notifyListeners();
  }

  void addGiderKalemi(String kalem) {
    if (!_giderKalemleri.contains(kalem)) {
      _giderKalemleri.add(kalem);
      _saveUserSettings();
      notifyListeners();
    }
  }

  void removeGiderKalemi(String kalem) {
    _giderKalemleri.remove(kalem);
    _saveUserSettings();
    notifyListeners();
  }

  void addPersonel(String personel) {
    if (!_personeller.contains(personel)) {
      _personeller.add(personel);
      _saveUserSettings();
      notifyListeners();
    }
  }

  void removePersonel(String personel) {
    _personeller.remove(personel);
    _saveUserSettings();
    notifyListeners();
  }

  void addCari(String cari) {
    if (!_cariler.contains(cari)) {
      _cariler.add(cari);
      _saveUserSettings();
      notifyListeners();
    }
  }

  void removeCari(String cari) {
    _cariler.remove(cari);
    _saveUserSettings();
    notifyListeners();
  }

  String getEffectiveUser() {
    if (_isAdmin && _selectedUserForAdmin.isNotEmpty) {
      return _selectedUserForAdmin;
    }
    return _currentUser;
  }
}
// 2.1 AppSettings Sınıfı SONU ******************************************************************

// 2.2 DataProvider Sınıfı ******************************************************************
class DataProvider with ChangeNotifier {
  List<Map<String, dynamic>> _tonajKayitlari = [];
  List<Map<String, dynamic>> _giderKayitlari = [];
  List<Map<String, dynamic>> _faturaKayitlari = [];
  List<Map<String, dynamic>> _tahsilatKayitlari = [];
  List<Map<String, dynamic>> _maasTahakkuklari = [];
  List<Map<String, dynamic>> _maasOdemeleri = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> get tonajKayitlari => _tonajKayitlari;
  List<Map<String, dynamic>> get giderKayitlari => _giderKayitlari;
  List<Map<String, dynamic>> get faturaKayitlari => _faturaKayitlari;
  List<Map<String, dynamic>> get tahsilatKayitlari => _tahsilatKayitlari;
  List<Map<String, dynamic>> get maasTahakkuklari => _maasTahakkuklari;
  List<Map<String, dynamic>> get maasOdemeleri => _maasOdemeleri;

  // Firestore'dan verileri yükle
  Future<void> loadAllData() async {
    await _loadTonajKayitlari();
    await _loadGiderKayitlari();
    await _loadFaturaKayitlari();
    await _loadTahsilatKayitlari();
    await _loadMaasTahakkuklari();
    await _loadMaasOdemeleri();
  }

  Future<void> _loadTonajKayitlari() async {
    try {
      final snapshot = await _firestore.collection('tonajKayitlari').orderBy('tarih', descending: true).get();
      _tonajKayitlari = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Tonaj kayıtları yüklenirken hata: $e');
    }
  }

  Future<void> _loadGiderKayitlari() async {
    try {
      final snapshot = await _firestore.collection('giderKayitlari').orderBy('tarih', descending: true).get();
      _giderKayitlari = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Gider kayıtları yüklenirken hata: $e');
    }
  }

  Future<void> _loadFaturaKayitlari() async {
    try {
      final snapshot = await _firestore.collection('faturaKayitlari').orderBy('tarih', descending: true).get();
      _faturaKayitlari = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Fatura kayıtları yüklenirken hata: $e');
    }
  }

  Future<void> _loadTahsilatKayitlari() async {
    try {
      final snapshot = await _firestore.collection('tahsilatKayitlari').orderBy('tarih', descending: true).get();
      _tahsilatKayitlari = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Tahsilat kayıtları yüklenirken hata: $e');
    }
  }

  Future<void> _loadMaasTahakkuklari() async {
    try {
      final snapshot = await _firestore.collection('maasTahakkuklari').orderBy('tarih', descending: true).get();
      _maasTahakkuklari = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Maaş tahakkukları yüklenirken hata: $e');
    }
  }

  Future<void> _loadMaasOdemeleri() async {
    try {
      final snapshot = await _firestore.collection('maasOdemeleri').orderBy('tarih', descending: true).get();
      _maasOdemeleri = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      notifyListeners();
    } catch (e) {
      print('Maaş ödemeleri yüklenirken hata: $e');
    }
  }

  // Kullanıcı bazlı veri işlemleri
  String _getUserField() {
    final settings = Provider.of<AppSettings>(navigatorKey.currentContext!, listen: false);
    return settings.getEffectiveUser();
  }

  // Tonaj kaydı ekle - FIREBASE'E YAZMA
  void addTonajKaydi(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('tonajKayitlari').add(kayit);
      kayit['id'] = docRef.id;
      _tonajKayitlari.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _tonajKayitlari.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateTonajKaydi(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _tonajKayitlari.length) {
      try {
        final id = _tonajKayitlari[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('tonajKayitlari').doc(id).update(kayit);
        }
        _tonajKayitlari[index] = kayit;
        notifyListeners();
      } catch (e) {
        _tonajKayitlari[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteTonajKaydi(int index) async {
    if (index >= 0 && index < _tonajKayitlari.length) {
      try {
        final id = _tonajKayitlari[index]['id'];
        if (id != null) {
          await _firestore.collection('tonajKayitlari').doc(id).delete();
        }
        _tonajKayitlari.removeAt(index);
        notifyListeners();
      } catch (e) {
        _tonajKayitlari.removeAt(index);
        notifyListeners();
      }
    }
  }

  void addGiderKaydi(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('giderKayitlari').add(kayit);
      kayit['id'] = docRef.id;
      _giderKayitlari.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _giderKayitlari.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateGiderKaydi(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _giderKayitlari.length) {
      try {
        final id = _giderKayitlari[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('giderKayitlari').doc(id).update(kayit);
        }
        _giderKayitlari[index] = kayit;
        notifyListeners();
      } catch (e) {
        _giderKayitlari[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteGiderKaydi(int index) async {
    if (index >= 0 && index < _giderKayitlari.length) {
      try {
        final id = _giderKayitlari[index]['id'];
        if (id != null) {
          await _firestore.collection('giderKayitlari').doc(id).delete();
        }
        _giderKayitlari.removeAt(index);
        notifyListeners();
      } catch (e) {
        _giderKayitlari.removeAt(index);
        notifyListeners();
      }
    }
  }

  void addFaturaKaydi(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('faturaKayitlari').add(kayit);
      kayit['id'] = docRef.id;
      _faturaKayitlari.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _faturaKayitlari.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateFaturaKaydi(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _faturaKayitlari.length) {
      try {
        final id = _faturaKayitlari[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('faturaKayitlari').doc(id).update(kayit);
        }
        _faturaKayitlari[index] = kayit;
        notifyListeners();
      } catch (e) {
        _faturaKayitlari[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteFaturaKaydi(int index) async {
    if (index >= 0 && index < _faturaKayitlari.length) {
      try {
        final id = _faturaKayitlari[index]['id'];
        if (id != null) {
          await _firestore.collection('faturaKayitlari').doc(id).delete();
        }
        _faturaKayitlari.removeAt(index);
        notifyListeners();
      } catch (e) {
        _faturaKayitlari.removeAt(index);
        notifyListeners();
      }
    }
  }

  void addTahsilatKaydi(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('tahsilatKayitlari').add(kayit);
      kayit['id'] = docRef.id;
      _tahsilatKayitlari.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _tahsilatKayitlari.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateTahsilatKaydi(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _tahsilatKayitlari.length) {
      try {
        final id = _tahsilatKayitlari[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('tahsilatKayitlari').doc(id).update(kayit);
        }
        _tahsilatKayitlari[index] = kayit;
        notifyListeners();
      } catch (e) {
        _tahsilatKayitlari[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteTahsilatKaydi(int index) async {
    if (index >= 0 && index < _tahsilatKayitlari.length) {
      try {
        final id = _tahsilatKayitlari[index]['id'];
        if (id != null) {
          await _firestore.collection('tahsilatKayitlari').doc(id).delete();
        }
        _tahsilatKayitlari.removeAt(index);
        notifyListeners();
      } catch (e) {
        _tahsilatKayitlari.removeAt(index);
        notifyListeners();
      }
    }
  }

  void addMaasTahakkuku(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('maasTahakkuklari').add(kayit);
      kayit['id'] = docRef.id;
      _maasTahakkuklari.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _maasTahakkuklari.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateMaasTahakkuku(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _maasTahakkuklari.length) {
      try {
        final id = _maasTahakkuklari[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('maasTahakkuklari').doc(id).update(kayit);
        }
        _maasTahakkuklari[index] = kayit;
        notifyListeners();
      } catch (e) {
        _maasTahakkuklari[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteMaasTahakkuku(int index) async {
    if (index >= 0 && index < _maasTahakkuklari.length) {
      try {
        final id = _maasTahakkuklari[index]['id'];
        if (id != null) {
          await _firestore.collection('maasTahakkuklari').doc(id).delete();
        }
        _maasTahakkuklari.removeAt(index);
        notifyListeners();
      } catch (e) {
        _maasTahakkuklari.removeAt(index);
        notifyListeners();
      }
    }
  }

  void addMaasOdeme(Map<String, dynamic> kayit) async {
    try {
      kayit['userId'] = _getUserField();
      final docRef = await _firestore.collection('maasOdemeleri').add(kayit);
      kayit['id'] = docRef.id;
      _maasOdemeleri.insert(0, kayit);
      notifyListeners();
    } catch (e) {
      kayit['userId'] = _getUserField();
      _maasOdemeleri.insert(0, kayit);
      notifyListeners();
    }
  }

  void updateMaasOdeme(int index, Map<String, dynamic> kayit) async {
    if (index >= 0 && index < _maasOdemeleri.length) {
      try {
        final id = _maasOdemeleri[index]['id'];
        kayit['userId'] = _getUserField();
        if (id != null) {
          await _firestore.collection('maasOdemeleri').doc(id).update(kayit);
        }
        _maasOdemeleri[index] = kayit;
        notifyListeners();
      } catch (e) {
        _maasOdemeleri[index] = kayit;
        notifyListeners();
      }
    }
  }

  void deleteMaasOdeme(int index) async {
    if (index >= 0 && index < _maasOdemeleri.length) {
      try {
        final id = _maasOdemeleri[index]['id'];
        if (id != null) {
          await _firestore.collection('maasOdemeleri').doc(id).delete();
        }
        _maasOdemeleri.removeAt(index);
        notifyListeners();
      } catch (e) {
        _maasOdemeleri.removeAt(index);
        notifyListeners();
      }
    }
  }

  // Kullanıcı bazlı filtreleme
  List<Map<String, dynamic>> getFilteredTonajKayitlari(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _tonajKayitlari.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }

  List<Map<String, dynamic>> getFilteredGiderKayitlari(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _giderKayitlari.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }

  List<Map<String, dynamic>> getFilteredFaturaKayitlari(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _faturaKayitlari.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }

  List<Map<String, dynamic>> getFilteredTahsilatKayitlari(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _tahsilatKayitlari.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }

  List<Map<String, dynamic>> getFilteredMaasTahakkuklari(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _maasTahakkuklari.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }

  List<Map<String, dynamic>> getFilteredMaasOdemeleri(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final effectiveUser = settings.getEffectiveUser();
    return _maasOdemeleri.where((kayit) => kayit['userId'] == effectiveUser).toList();
  }
}

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// 2.2 DataProvider Sınıfı SONU ******************************************************************

// 2. BÖLÜM SONU ******************************************************************
// 3.1 PasswordScreen State Yönetimi ******************************************************************
class PasswordScreen extends StatefulWidget {
  @override
  _PasswordScreenState createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showAdminLogin = false;
  bool _firstAttempt = true;

  Future<void> _checkLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // DEBUG EKLENDİ
    print('=== GİRİŞ DENEMESİ BAŞLADI ===');
    print('Kullanıcı adı: ${_usernameController.text}');
    print('Şifre: ${_passwordController.text}');
    print('Admin modu: $_showAdminLogin'); // BU ÇOK ÖNEMLİ!

    final settings = Provider.of<AppSettings>(context, listen: false);

    // DEBUG: AppSettings durumunu kontrol et
    print('AppSettings admin kullanıcı: ${settings.adminUsername}');
    print('AppSettings admin şifre: ${settings.adminPassword}');
    print('AppSettings kullanıcı listesi: ${settings.kullanicilar}');

    bool loginSuccess = false;

    if (_showAdminLogin) {
      print('🔐 ADMIN GİRİŞİ KONTROL EDİLİYOR...');
      print('Beklenen: ${settings.adminUsername}/${settings.adminPassword}');
      print('Girilen: ${_usernameController.text}/${_passwordController.text}');

      if (_usernameController.text == settings.adminUsername &&
          _passwordController.text == settings.adminPassword) {
        print('✅ ADMIN GİRİŞİ BAŞARILI!');
        settings.setCurrentUser('admin', true);
        loginSuccess = true;
      } else {
        print('❌ ADMIN GİRİŞİ BAŞARISIZ!');
      }
    } else {
      print('👤 NORMAL KULLANICI GİRİŞİ KONTROL EDİLİYOR...');
      if (settings.kullanicilar.containsKey(_usernameController.text) &&
          settings.kullanicilar[_usernameController.text]!['password'] == _passwordController.text) {
        print('✅ KULLANICI GİRİŞİ BAŞARILI: ${_usernameController.text}');
        settings.setCurrentUser(_usernameController.text, false);
        loginSuccess = true;
      } else {
        print('❌ KULLANICI GİRİŞİ BAŞARISIZ!');
      }
    }

    if (loginSuccess) {
      print('🎉 GİRİŞ BAŞARILI - Ana sayfaya yönlendiriliyor...');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainApp()),
      );
    } else {
      print('💥 GİRİŞ BAŞARISIZ - Hata gösteriliyor');
      _showError(_showAdminLogin ? 'Admin giriş bilgileri hatalı!' : 'Kullanıcı adı veya şifre hatalı!');
      _firstAttempt = false;
    }

    setState(() {
      _isLoading = false;
    });
    print('=== GİRİŞ DENEMESİ TAMAMLANDI ===');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAdminLoginDialog() {
    setState(() {
      _showAdminLogin = true;
      _usernameController.text = '';
      _passwordController.text = '';
      _firstAttempt = true;
    });
  }
// 3.1 PasswordScreen State Yönetimi SONU ******************************************************************

// 3.2 Giriş Kontrolleri ******************************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          width: 350,
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Hakediş Takip',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'by emrah yılmazer',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 20),

              // DEBUG: Admin modu durumunu göster
              if (_showAdminLogin) ...[
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.amber.shade700, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'ADMİN GİRİŞİ MODU AKTİF',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'ADMİN GİRİŞİ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
                SizedBox(height: 10),
              ],

              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: _showAdminLogin ? 'Admin Kullanıcı Adı' : 'Kullanıcı Adı',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.amber.shade700),
                  ),
                  prefixIcon: Icon(Icons.person, color: Colors.grey.shade600),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                onChanged: (_) {
                  if (!_firstAttempt) {
                    setState(() {
                      _firstAttempt = true;
                    });
                  }
                },
              ),
              SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.amber.shade700),
                  ),
                  prefixIcon: Icon(Icons.lock, color: Colors.grey.shade600),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                onChanged: (_) {
                  if (!_firstAttempt) {
                    setState(() {
                      _firstAttempt = true;
                    });
                  }
                },
                onSubmitted: (_) => _checkLogin(),
              ),
              SizedBox(height: 25),

              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _checkLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  _showAdminLogin ? 'ADMİN GİRİŞİ' : 'GİRİŞ YAP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              SizedBox(height: 15),

              if (!_showAdminLogin) ...[
                TextButton(
                  onPressed: () {
                    print('🔄 Admin girişi butonuna tıklandı');
                    setState(() {
                      _showAdminLogin = true;
                      _usernameController.text = '';
                      _passwordController.text = '';
                      _firstAttempt = true;
                    });
                    print('✅ Admin modu aktif: $_showAdminLogin');
                  },
                  child: Text(
                    'ADMİN GİRİŞİ',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              if (_showAdminLogin) ...[
                TextButton(
                  onPressed: () {
                    print('🔄 Geri butonuna tıklandı');
                    setState(() {
                      _showAdminLogin = false;
                      _usernameController.text = '';
                      _passwordController.text = '';
                      _firstAttempt = true;
                    });
                    print('✅ Admin modu kapatıldı: $_showAdminLogin');
                  },
                  child: Text(
                    '← Geri',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
// 3.2 Giriş Kontrolleri SONU ******************************************************************

// 3. BÖLÜM SONU ******************************************************************
// 4.1 MainApp State Yönetimi ******************************************************************
class MainApp extends StatefulWidget {
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Firebase verilerini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.loadAllData();

      // DEBUG: Kullanıcı durumunu kontrol et
      final settings = Provider.of<AppSettings>(context, listen: false);
      print('🏠 MainApp başlatıldı');
      print('🏠 Current User: ${settings.currentUser}');
      print('🏠 Is Admin: ${settings.isAdmin}');
      print('🏠 Selected User: ${settings.selectedUserForAdmin}');
    });
  }

  @override
  Widget build(BuildContext context) {
    print('=== MAINAPP REBUILD ===');
    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAnaEkranAppBar() : _buildNormalAppBar(),
      body: Consumer<AppSettings>(
        builder: (context, settings, child) {
          print('📱 MainApp Consumer - currentUser: ${settings.currentUser}');
          print('📱 MainApp Consumer - isAdmin: ${settings.isAdmin}');
          print('📱 MainApp Consumer - selectedUserForAdmin: ${settings.selectedUserForAdmin}');
          return _buildCurrentPage();
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0: return AnaEkran();
      case 1: return TonajKayitlari();
      case 2: return GiderKayitlari();
      case 3: return CariSayfasi();
      case 4: return PersonelSayfasi();
      case 5: return AyarlarSayfasi();
      default: return AnaEkran();
    }
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.amber.shade800,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, color: Colors.amber.shade700),
          label: 'ANA EKRAN',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping, color: Colors.amber.shade700),
          label: 'TONAJ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.money_off, color: Colors.amber.shade700),
          label: 'GİDER',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.attach_money, color: Colors.amber.shade700),
          label: 'CARİ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people, color: Colors.amber.shade700),
          label: 'PERSONEL',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings, color: Colors.amber.shade700),
          label: 'AYARLAR',
        ),
      ],
    );
  }
// 4.1 MainApp State Yönetimi SONU ******************************************************************

// 4.2 BottomNavigationBar Sistemi ******************************************************************
  PreferredSizeWidget _buildAnaEkranAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade600, Colors.amber.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: -50,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: 150,
                  height: 30,
                  color: Colors.grey.shade800.withOpacity(0.3),
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: -80,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: 200,
                  height: 30,
                  color: Colors.grey.shade800.withOpacity(0.2),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: -50,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  width: 150,
                  height: 30,
                  color: Colors.grey.shade800.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Icon(Icons.local_shipping, color: Colors.grey.shade800, size: 28),
          SizedBox(width: 10),
          Text(
            'Hakediş Takip',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        // DEĞİŞİKLİK: Sadece admin kontrolü - kullanıcı listesi kontrolü kaldırıldı
        Consumer<AppSettings>(
          builder: (context, settings, child) {
            print('🎯 APPBAR Consumer - isAdmin: ${settings.isAdmin}');
            print('🎯 APPBAR Consumer - kullanıcı sayısı: ${settings.kullanicilar.length}');
            if (settings.isAdmin) {
              print('🎯 ADMIN MODU AKTİF - Kullanıcı seçici gösteriliyor');
              return _buildUserSelector(settings);
            } else {
              print('🎯 NORMAL KULLANICI MODU - Seçici gizleniyor');
              return SizedBox.shrink();
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.exit_to_app, color: Colors.grey.shade800),
          onPressed: () {
            _showCikisDialog(context);
          },
        ),
      ],
      elevation: 0,
    );
  }

  Widget _buildUserSelector(AppSettings settings) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: DropdownButton<String>(
        value: settings.selectedUserForAdmin.isNotEmpty ? settings.selectedUserForAdmin : null,
        hint: Text(
          'Kullanıcı Seç',
          style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
        ),
        icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade800),
        style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
        underline: Container(),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text('Tüm Kullanıcılar', style: TextStyle(fontSize: 12)),
          ),
          ...settings.kullanicilar.keys.map((username) {
            return DropdownMenuItem(
              value: username,
              child: Text(username, style: TextStyle(fontSize: 12)),
            );
          }).toList(),
        ],
        onChanged: (String? newValue) {
          settings.setSelectedUserForAdmin(newValue ?? '');
          // Verileri yeniden yükle
          final dataProvider = Provider.of<DataProvider>(context, listen: false);
          dataProvider.loadAllData();
        },
      ),
    );
  }

  void _showCikisDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Çıkış", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("Uygulamadan çıkmak istediğinize emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text("Çıkış"),
              onPressed: () {
                final settings = Provider.of<AppSettings>(context, listen: false);
                settings.setCurrentUser('', false);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => PasswordScreen()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    String title = '';

    switch (_currentIndex) {
      case 1:
        title = 'Tonaj Kayıtları';
        break;
      case 2:
        title = 'Gider Kayıtları';
        break;
      case 3:
        title = 'Cari Hesap';
        break;
      case 4:
        title = 'Personel İşlemleri';
        break;
      case 5:
        title = 'Ayarlar';
        break;
    }

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
      backgroundColor: Colors.amber.shade700,
      foregroundColor: Colors.grey.shade800,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
        onPressed: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
    );
  }
}
// 4.2 BottomNavigationBar Sistemi SONU ******************************************************************
// 4. BÖLÜM SONU ******************************************************************
// 5.1 AnaEkran State Yönetimi ******************************************************************
class AnaEkran extends StatefulWidget {
  @override
  _AnaEkranState createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final NumberFormat _numberFormat = NumberFormat.decimalPattern('tr');
  final NumberFormat _moneyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2);

  List<Map<String, dynamic>> _getFiltrelenmisKayitlar() {
    final data = Provider.of<DataProvider>(context, listen: false);
    final settings = Provider.of<AppSettings>(context, listen: false);

    // Kullanıcı bazlı filtreleme uygula
    var kayitlar = data.getFilteredTonajKayitlari(context);

    if (settings.sonAracFiltresi != 'Tümü') {
      kayitlar = kayitlar.where((k) => k['aracKodu'] == settings.sonAracFiltresi).toList();
    }

    if (settings.sonStartDate != null && settings.sonEndDate != null) {
      kayitlar = kayitlar.where((k) {
        final tarih = (k['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(settings.sonStartDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(settings.sonEndDate!.add(Duration(days: 1))));
      }).toList();
    }

    return kayitlar;
  }

  // GÜNCELLENDİ: Aynı güne ait kayıtları topla
  Map<String, Map<String, dynamic>> _gruplaKayitlarGunluk(List<Map<String, dynamic>> kayitlar) {
    Map<String, Map<String, dynamic>> gruplanmis = {};

    for (var kayit in kayitlar) {
      final tarih = _dateFormat.format((kayit['tarih'] as Timestamp).toDate());

      if (!gruplanmis.containsKey(tarih)) {
        gruplanmis[tarih] = {
          'tarih': tarih,
          'turSayisi': 0,
          'toplamDara': 0.0,
          'toplamBrut': 0.0,
          'toplamNet': 0.0,
          'toplamTutar': 0.0,
          'kayitSayisi': 0,
        };
      }

      // Aynı güne ait kayıtları topla
      gruplanmis[tarih]!['turSayisi'] += (kayit['turSayisi'] as int? ?? 0);
      gruplanmis[tarih]!['toplamDara'] += (kayit['toplamDara'] ?? 0).toDouble();
      gruplanmis[tarih]!['toplamBrut'] += (kayit['toplamBrut'] ?? 0).toDouble();
      gruplanmis[tarih]!['toplamNet'] += (kayit['toplamNet'] ?? 0).toDouble();
      gruplanmis[tarih]!['toplamTutar'] += (kayit['toplamTutar'] ?? 0).toDouble();
      gruplanmis[tarih]!['kayitSayisi'] += 1;
    }

    return gruplanmis;
  }

  double _getToplamGider() {
    final data = Provider.of<DataProvider>(context, listen: false);
    final settings = Provider.of<AppSettings>(context, listen: false);
    double toplam = 0;

    // Kullanıcı bazlı filtreleme uygula
    var giderler = data.getFilteredGiderKayitlari(context);

    if (settings.sonAracFiltresi != 'Tümü') {
      giderler = giderler.where((g) => g['aracKodu'] == settings.sonAracFiltresi).toList();
    }

    if (settings.sonStartDate != null && settings.sonEndDate != null) {
      giderler = giderler.where((g) {
        final tarih = (g['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(settings.sonStartDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(settings.sonEndDate!.add(Duration(days: 1))));
      }).toList();
    }

    for (var gider in giderler) {
      toplam += (gider['tutar'] ?? 0).toDouble();
    }

    return toplam;
  }

  Map<String, dynamic> _hesaplaToplamlar(List<Map<String, dynamic>> kayitlar) {
    int toplamTur = 0;
    double toplamDara = 0;
    double toplamBrut = 0;
    double toplamNet = 0;
    double toplamTutar = 0;

    for (var kayit in kayitlar) {
      toplamTur += (kayit['turSayisi'] as int? ?? 0);
      toplamDara += (kayit['toplamDara'] ?? 0).toDouble();
      toplamBrut += (kayit['toplamBrut'] ?? 0).toDouble();
      toplamNet += (kayit['toplamNet'] ?? 0).toDouble();
      toplamTutar += (kayit['toplamTutar'] ?? 0).toDouble();
    }

    final settings = Provider.of<AppSettings>(context, listen: false);
    double toplamGider = _getToplamGider();
    double kalan = toplamTutar - toplamGider;
    double kdv = kalan * (settings.kdvOrani / 100);
    double tevkifat = settings.tevkifatUygulansin ? (kdv * settings.tevkifatOrani) : 0;
    double faturaTutari = kalan + kdv - tevkifat;

    return {
      'toplamTur': toplamTur,
      'toplamDara': toplamDara,
      'toplamBrut': toplamBrut,
      'toplamNet': toplamNet,
      'toplamTutar': toplamTutar,
      'toplamGider': toplamGider,
      'kalan': kalan,
      'kdv': kdv,
      'tevkifat': tevkifat,
      'faturaTutari': faturaTutari,
    };
  }

  String _getRaporBasligi() {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String aracText = settings.sonAracFiltresi == 'Tümü'
        ? settings.araclar.join(', ')
        : settings.sonAracFiltresi;

    String tarihText = settings.sonStartDate != null && settings.sonEndDate != null
        ? '${_dateFormat.format(settings.sonStartDate!)} / ${_dateFormat.format(settings.sonEndDate!)}'
        : 'Tüm Tarihler';

    String kullaniciText = '';
    if (settings.isAdmin) {
      if (settings.selectedUserForAdmin.isEmpty) {
        kullaniciText = ' - Tüm Kullanıcılar';
      } else {
        kullaniciText = ' - ${settings.selectedUserForAdmin}';
      }
    } else {
      kullaniciText = ' - ${settings.currentUser}';
    }

    return '${settings.raporBasligi} $aracText Kodlu, $tarihText Tarihleri Arası$kullaniciText Hakediş Raporu';
  }
// 5.1 AnaEkran State Yönetimi SONU ******************************************************************

// 5.2 Filtreleme Sistemi ******************************************************************
  void _gosterFiltreDialog(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    DateTime? startDate = settings.sonStartDate;
    DateTime? endDate = settings.sonEndDate;
    String selectedArac = settings.sonAracFiltresi;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Row(
              children: [
                Icon(Icons.filter_alt, color: Colors.amber.shade700),
                SizedBox(width: 8),
                Text('Filtreler', style: TextStyle(color: Colors.grey.shade800)),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    color: Colors.amber.shade100,
                    child: ListTile(
                      leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                      title: Text('Tarih Filtresi', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(
                        startDate != null && endDate != null
                            ? '${_dateFormat.format(startDate!)} - ${_dateFormat.format(endDate!)}'
                            : 'Tüm Tarihler',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                      onTap: () async {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          currentDate: DateTime.now(),
                          saveText: 'Tamam',
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            startDate = picked.start;
                            endDate = picked.end;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    color: Colors.amber.shade100,
                    child: ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.grey.shade700),
                      title: Text('Araç Filtresi', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(selectedArac, style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.amber.shade50,
                            title: Text('Araç Seçin', style: TextStyle(color: Colors.grey.shade800)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text('TÜMÜ', style: TextStyle(color: Colors.grey.shade800)),
                                  trailing: selectedArac == 'Tümü' ? Icon(Icons.check, color: Colors.amber.shade700) : null,
                                  onTap: () {
                                    setState(() {
                                      selectedArac = 'Tümü';
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                ...settings.araclar.map((arac) => ListTile(
                                  title: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                                  trailing: selectedArac == arac ? Icon(Icons.check, color: Colors.amber.shade700) : null,
                                  onTap: () {
                                    setState(() {
                                      selectedArac = arac;
                                    });
                                    Navigator.pop(context);
                                  },
                                )).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    startDate = null;
                    endDate = null;
                    selectedArac = 'Tümü';
                  });
                },
                child: Text('Sıfırla', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('İptal', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () {
                  settings.setFiltreler(startDate, endDate, selectedArac);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Uygula'),
              ),
            ],
          );
        },
      ),
    );
  }
// 5.2 Filtreleme Sistemi SONU ******************************************************************

// 5.3 PDF Rapor Oluşturma ******************************************************************
  Future<void> _pdfOlusturVePaylas() async {
    try {
      final pdf = pw.Document();
      final settings = Provider.of<AppSettings>(context, listen: false);
      final data = Provider.of<DataProvider>(context, listen: false);

      final kayitlar = _getFiltrelenmisKayitlar();
      final gruplanmisKayitlar = _gruplaKayitlarGunluk(kayitlar);
      final toplamlar = _hesaplaToplamlar(kayitlar);

      final font = await PdfGoogleFonts.nunitoSansRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  _getRaporBasligi(),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: font),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                headerDecoration: pw.BoxDecoration(color: PdfColors.amber100),
                headers: ['Tarih', 'Tur Sayısı', 'Toplam Dara', 'Toplam Brüt', 'Toplam Net', 'Toplam Tutar', 'Kayıt Sayısı'],
                data: gruplanmisKayitlar.values.map((gunluk) {
                  return [
                    gunluk['tarih'],
                    _numberFormat.format(gunluk['turSayisi']),
                    '${_numberFormat.format((gunluk['toplamDara'] ?? 0) / 1000)} ton',
                    '${_numberFormat.format((gunluk['toplamBrut'] ?? 0) / 1000)} ton',
                    '${_numberFormat.format((gunluk['toplamNet'] ?? 0) / 1000)} ton',
                    '${_moneyFormat.format(gunluk['toplamTutar'] ?? 0)} ₺',
                    _numberFormat.format(gunluk['kayitSayisi']),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Hakediş: ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['toplamTutar'])} ₺', style: pw.TextStyle(font: font)),
                    pw.Text('Gider: ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['toplamGider'])} ₺', style: pw.TextStyle(font: font)),
                    pw.Text('Kalan: ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['kalan'])} ₺', style: pw.TextStyle(font: font)),
                    pw.Text('KDV (%${settings.kdvOrani}): ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['kdv'])} ₺', style: pw.TextStyle(font: font)),
                    if (settings.tevkifatUygulansin)
                      pw.Text('Tevkifat (%${(settings.tevkifatOrani * 100).toInt()}): ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['tevkifat'])} ₺', style: pw.TextStyle(font: font)),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(color: PdfColors.amber100),
                      child: pw.Text(
                        'Fatura Tutarı: ${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamlar['faturaTutari'])} ₺',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, font: font),
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'hakedis-raporu-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF başarıyla oluşturuldu ve paylaşıma hazır!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata: $e')),
      );
    }
  }
// 5.3 PDF Rapor Oluşturma SONU ******************************************************************

// 5.4 AnaEkran Build Metodu ******************************************************************
  @override
  Widget build(BuildContext context) {
    final kayitlar = _getFiltrelenmisKayitlar();
    final gruplanmisKayitlar = _gruplaKayitlarGunluk(kayitlar);
    final toplamlar = _hesaplaToplamlar(kayitlar);
    final settings = Provider.of<AppSettings>(context);

    List<String> tarihListesi = gruplanmisKayitlar.keys.toList()..sort((a, b) => b.compareTo(a));

    // Tarih aralığındaki tüm günleri değil, sadece veri olan günleri göster
    if (settings.sonStartDate != null && settings.sonEndDate != null && tarihListesi.isEmpty) {
      DateTime current = settings.sonStartDate!;
      while (current.isBefore(settings.sonEndDate!.add(Duration(days: 1)))) {
        final tarihStr = _dateFormat.format(current);
        if (!tarihListesi.contains(tarihStr)) {
          tarihListesi.add(tarihStr);
        }
        current = current.add(Duration(days: 1));
      }
      tarihListesi.sort((a, b) => b.compareTo(a));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Kullanıcı bilgisi
          if (settings.isAdmin)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Görüntülenen: ${settings.selectedUserForAdmin.isEmpty ? 'Tüm Kullanıcılar' : settings.selectedUserForAdmin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _gosterFiltreDialog(context),
                    icon: Icon(Icons.filter_alt),
                    label: Text('FİLTRE UYGULA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade800, width: 1),
                      ),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pdfOlusturVePaylas,
                    icon: Icon(Icons.picture_as_pdf),
                    label: Text('RAPORLA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade800, width: 1),
                      ),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (settings.sonStartDate != null && settings.sonEndDate != null)
            Container(
              padding: EdgeInsets.all(16),
              child: Text(
                _getRaporBasligi(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                children: [
                  Container(
                    color: Colors.amber.shade100,
                    child: Row(
                      children: [
                        _buildTableHeader('TARİH', 90),
                        _buildTableHeader('TUR\nSAYISI', 70),
                        _buildTableHeader('TOPLAM\nDARA', 90),
                        _buildTableHeader('TOPLAM\nBRÜT', 90),
                        _buildTableHeader('TOPLAM\nNET', 90),
                        _buildTableHeader('TOPLAM\nTUTAR', 90),
                        _buildTableHeader('KAYIT\nSAYISI', 70),
                      ],
                    ),
                  ),

                  ...tarihListesi.map((tarih) {
                    var gunlukVeri = gruplanmisKayitlar[tarih];

                    return Container(
                      color: _getRowColor(tarihListesi.indexOf(tarih)),
                      child: Row(
                        children: [
                          _buildTableCell(tarih, 90),
                          _buildTableCell(
                              gunlukVeri != null ? _formatNumber(gunlukVeri['turSayisi']) : '-',
                              70
                          ),
                          _buildTableCell(
                              gunlukVeri != null ? '${_formatNumber((gunlukVeri['toplamDara'] ?? 0) / 1000)} ton' : '-',
                              90
                          ),
                          _buildTableCell(
                              gunlukVeri != null ? '${_formatNumber((gunlukVeri['toplamBrut'] ?? 0) / 1000)} ton' : '-',
                              90
                          ),
                          _buildTableCell(
                              gunlukVeri != null ? '${_formatNumber((gunlukVeri['toplamNet'] ?? 0) / 1000)} ton' : '-',
                              90
                          ),
                          _buildTableCell(
                              gunlukVeri != null ? '${_formatMoney(gunlukVeri['toplamTutar'] ?? 0)} ₺' : '-',
                              90,
                              isMoney: gunlukVeri != null
                          ),
                          _buildTableCell(
                              gunlukVeri != null ? _formatNumber(gunlukVeri['kayitSayisi']) : '-',
                              70
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  Container(
                    color: Colors.amber.shade200,
                    child: Row(
                      children: [
                        _buildTableHeader('GENEL\nTOPLAM', 90, isTotal: true),
                        _buildTableHeader(_formatNumber(toplamlar['toplamTur']), 70, isTotal: true),
                        _buildTableHeader('${_formatNumber(toplamlar['toplamDara'] / 1000)} ton', 90, isTotal: true),
                        _buildTableHeader('${_formatNumber(toplamlar['toplamBrut'] / 1000)} ton', 90, isTotal: true),
                        _buildTableHeader('${_formatNumber(toplamlar['toplamNet'] / 1000)} ton', 90, isTotal: true),
                        _buildTableHeader('${_formatMoney(toplamlar['toplamTutar'])} ₺', 90, isTotal: true),
                        _buildTableHeader(_formatNumber(kayitlar.length), 70, isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildHesaplamaSatiri('HAKEDİŞ', toplamlar['toplamTutar']),
                _buildHesaplamaSatiri('GİDER', toplamlar['toplamGider']),
                _buildHesaplamaSatiri('KALAN', toplamlar['kalan'], isBold: true),
                _buildHesaplamaSatiri('KDV (%${Provider.of<AppSettings>(context).kdvOrani})', toplamlar['kdv']),
                if (Provider.of<AppSettings>(context).tevkifatUygulansin)
                  _buildHesaplamaSatiri('TEVKİFAT (%${(Provider.of<AppSettings>(context).tevkifatOrani * 100).toInt()})', toplamlar['tevkifat']),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'FATURA TUTARI:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${_formatMoney(toplamlar['faturaTutari'])} ₺',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, double width, {bool isTotal = false}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, double width, {bool isMoney = false}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isMoney ? FontWeight.bold : FontWeight.normal,
            color: isMoney ? Colors.green.shade700 : Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildHesaplamaSatiri(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Spacer(),
          Text(
            '${_formatMoney(value)} ₺',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '';
    final numValue = number is int ? number.toDouble() : number;
    return NumberFormat.decimalPattern('tr').format(numValue);
  }

  String _formatMoney(double amount) {
    return NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(amount);
  }

  Color _getRowColor(int index) {
    return index % 2 == 0 ? Colors.white : Colors.grey.shade50;
  }
}
// 5.4 AnaEkran Build Metodu SONU ******************************************************************

// 5. BÖLÜM SONU ******************************************************************
// 6.1 TonajKayitlari State Yönetimi ******************************************************************
class TonajKayitlari extends StatefulWidget {
  @override
  _TonajKayitlariState createState() => _TonajKayitlariState();
}

class _TonajKayitlariState extends State<TonajKayitlari> {
  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final settings = Provider.of<AppSettings>(context);

    // Kullanıcı bazlı filtreleme uygula
    final filteredKayitlar = data.getFilteredTonajKayitlari(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tonaj Kayıtları', style: TextStyle(color: Colors.grey.shade800)),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.grey.shade800,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi
          if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Kullanıcı: ${settings.selectedUserForAdmin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showTonajKayitEkle(context),
              icon: Icon(Icons.add),
              label: Text('YENİ TONAJ KAYDI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
                shadowColor: Colors.grey.shade800,
              ),
            ),
          ),

          Container(
            color: Colors.amber.shade100,
            child: Row(
              children: [
                _buildListHeader('Tarih', 1),
                _buildListHeader('Araç', 1),
                _buildListHeader('Sefer', 1),
                _buildListHeader('Net Tonaj', 1),
                _buildListHeader('Tutar', 1),
                _buildListHeader('', 1),
              ],
            ),
          ),

          Expanded(
            child: filteredKayitlar.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                  SizedBox(height: 16),
                  Text(
                    'Henüz tonaj kaydı bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yeni tonaj kaydı eklemek için butona tıklayın',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredKayitlar.length,
              itemBuilder: (context, index) {
                final kayit = filteredKayitlar[index];
                return _buildTonajKayitItem(kayit, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(String text, double flex) {
    return Expanded(
      flex: flex.toInt(),
      child: Container(
        padding: EdgeInsets.all(8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTonajKayitItem(Map<String, dynamic> kayit, int index) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final dateFormat = DateFormat('dd.MM.yyyy');
    final numberFormat = NumberFormat.decimalPattern('tr');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        height: 35,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  kayit['aracKodu'].toString(),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  numberFormat.format(kayit['turSayisi']),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${numberFormat.format((kayit['toplamNet'] ?? 0) / 1000)} ton',
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['toplamTutar'] ?? 0)} TL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 14),
                    onPressed: () => _showTonajKayitDuzenle(context, kayit, index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 14, color: Colors.red),
                    onPressed: () {
                      _showSilmeOnayDialog(context, () {
                        // Önce listedeki index'i bul
                        final filteredKayitlar = data.getFilteredTonajKayitlari(context);
                        final globalIndex = data.tonajKayitlari.indexWhere((k) => k['id'] == kayit['id']);

                        if (globalIndex != -1) {
                          data.deleteTonajKaydi(globalIndex);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kayıt silindi')),
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSilmeOnayDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Silme Onayı", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("Bu kaydı silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }
// 6.1 TonajKayitlari State Yönetimi SONU ******************************************************************

// 6.2 Tonaj Ekleme/Düzenleme ******************************************************************
  void _showTonajKayitEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedArac = settings.araclar.isNotEmpty ? settings.araclar.first : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController turController = TextEditingController();
    TextEditingController daraController = TextEditingController();
    TextEditingController brutController = TextEditingController();
    TextEditingController netController = TextEditingController();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void hesapla() {
            if (daraController.text.isNotEmpty && brutController.text.isNotEmpty) {
              double dara = double.tryParse(daraController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              double brut = double.tryParse(brutController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              double toplamNet = brut - dara;
              double toplamTutar = (toplamNet / 1000) * settings.tonajBirimFiyat;

              netController.text = NumberFormat.decimalPattern('tr').format(toplamNet);
              tutarController.text = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamTutar);
            }
          }

          return AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text('Yeni Tonaj Kaydı', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedArac,
                      items: settings.araclar.map((arac) {
                        return DropdownMenuItem(
                          value: arac,
                          child: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedArac = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Araç Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: turController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tur Sayısı',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: daraController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Toplam Dara (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                      onChanged: (_) => hesapla(),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: brutController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Toplam Brüt (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                      onChanged: (_) => hesapla(),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: netController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Net Tonaj (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Toplam Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (turController.text.isNotEmpty && daraController.text.isNotEmpty && brutController.text.isNotEmpty) {
                    final data = Provider.of<DataProvider>(context, listen: false);

                    double dara = double.parse(daraController.text.replaceAll('.', '').replaceAll(',', ''));
                    double brut = double.parse(brutController.text.replaceAll('.', '').replaceAll(',', ''));
                    double toplamNet = brut - dara;

                    // TUTARI YENİDEN HESAPLAYARAK KAYDET
                    double netTon = toplamNet / 1000;
                    double toplamTutar = netTon * settings.tonajBirimFiyat;

                    data.addTonajKaydi({
                      'tarih': Timestamp.fromDate(selectedDate),
                      'aracKodu': selectedArac,
                      'turSayisi': int.parse(turController.text),
                      'toplamDara': dara,
                      'toplamBrut': brut,
                      'toplamNet': toplamNet,
                      'toplamTutar': toplamTutar,
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tonaj kaydı başarıyla eklendi')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: child,
    );
  }

  void _showTonajKayitDuzenle(BuildContext context, Map<String, dynamic> kayit, int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final numberFormat = NumberFormat.decimalPattern('tr');

    // Global index'i bul
    final globalIndex = data.tonajKayitlari.indexWhere((k) => k['id'] == kayit['id']);

    String selectedArac = kayit['aracKodu'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController turController = TextEditingController(text: kayit['turSayisi'].toString());
    TextEditingController daraController = TextEditingController(text: numberFormat.format(kayit['toplamDara']));
    TextEditingController brutController = TextEditingController(text: numberFormat.format(kayit['toplamBrut']));
    TextEditingController netController = TextEditingController(text: numberFormat.format(kayit['toplamNet']));
    TextEditingController tutarController = TextEditingController(text: NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['toplamTutar']));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void hesapla() {
            if (daraController.text.isNotEmpty && brutController.text.isNotEmpty) {
              double dara = double.tryParse(daraController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              double brut = double.tryParse(brutController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
              double toplamNet = brut - dara;
              double toplamTutar = (toplamNet / 1000) * Provider.of<AppSettings>(context).tonajBirimFiyat;

              netController.text = numberFormat.format(toplamNet);
              tutarController.text = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(toplamTutar);
            }
          }

          return AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text('Tonaj Kaydını Düzenle', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedArac,
                      items: Provider.of<AppSettings>(context).araclar.map((arac) {
                        return DropdownMenuItem(
                          value: arac,
                          child: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedArac = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Araç Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: turController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tur Sayısı',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: daraController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Toplam Dara (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                      onChanged: (_) => hesapla(),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: brutController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Toplam Brüt (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                      onChanged: (_) => hesapla(),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: netController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Net Tonaj (kg)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Toplam Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (turController.text.isNotEmpty && daraController.text.isNotEmpty && brutController.text.isNotEmpty) {
                    double toplamNet = double.tryParse(netController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                    double toplamTutar = (toplamNet / 1000) * Provider.of<AppSettings>(context, listen: false).tonajBirimFiyat;

                    if (globalIndex != -1) {
                      data.updateTonajKaydi(globalIndex, {
                        'tarih': Timestamp.fromDate(selectedDate),
                        'aracKodu': selectedArac,
                        'turSayisi': int.parse(turController.text),
                        'toplamDara': double.parse(daraController.text.replaceAll('.', '').replaceAll(',', '')),
                        'toplamBrut': double.parse(brutController.text.replaceAll('.', '').replaceAll(',', '')),
                        'toplamNet': toplamNet,
                        'toplamTutar': toplamTutar,
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tonaj kaydı başarıyla güncellendi')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }
}
// 6.2 Tonaj Ekleme/Düzenleme SONU ******************************************************************

// 6. BÖLÜM SONU ******************************************************************
// 7.1 GiderKayitlari State Yönetimi ******************************************************************
class GiderKayitlari extends StatefulWidget {
  @override
  _GiderKayitlariState createState() => _GiderKayitlariState();
}

class _GiderKayitlariState extends State<GiderKayitlari> {
  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final settings = Provider.of<AppSettings>(context);

    // Kullanıcı bazlı filtreleme uygula
    final filteredKayitlar = data.getFilteredGiderKayitlari(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gider Kayıtları', style: TextStyle(color: Colors.grey.shade800)),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.grey.shade800,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi
          if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Kullanıcı: ${settings.selectedUserForAdmin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showGiderKayitEkle(context),
              icon: Icon(Icons.add),
              label: Text('YENİ GİDER KAYDI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
                shadowColor: Colors.grey.shade800,
              ),
            ),
          ),

          Container(
            color: Colors.amber.shade100,
            child: Row(
              children: [
                _buildListHeader('Tarih', 1),
                _buildListHeader('Araç', 1),
                _buildListHeader('Gider', 1),
                _buildListHeader('Tutar', 1),
                _buildListHeader('', 1),
              ],
            ),
          ),

          Expanded(
            child: filteredKayitlar.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                  SizedBox(height: 16),
                  Text(
                    'Henüz gider kaydı bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yeni gider kaydı eklemek için butona tıklayın',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredKayitlar.length,
              itemBuilder: (context, index) {
                final kayit = filteredKayitlar[index];
                return _buildGiderKayitItem(kayit, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(String text, double flex) {
    return Expanded(
      flex: flex.toInt(),
      child: Container(
        padding: EdgeInsets.all(8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGiderKayitItem(Map<String, dynamic> kayit, int index) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        height: 35,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  kayit['aracKodu'].toString(),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  kayit['giderAdi'].toString(),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tutar'] ?? 0)} TL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 14),
                    onPressed: () => _showGiderKayitDuzenle(context, kayit, index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 14, color: Colors.red),
                    onPressed: () {
                      _showSilmeOnayDialog(context, () {
                        // Önce listedeki index'i bul
                        final globalIndex = data.giderKayitlari.indexWhere((k) => k['id'] == kayit['id']);

                        if (globalIndex != -1) {
                          data.deleteGiderKaydi(globalIndex);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gider kaydı silindi')),
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSilmeOnayDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Silme Onayı", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("Bu gider kaydını silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }
// 7.1 GiderKayitlari State Yönetimi SONU ******************************************************************

// 7.2 Gider Ekleme/Düzenleme ******************************************************************
  void _showGiderKayitEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedArac = settings.araclar.isNotEmpty ? settings.araclar.first : '';
    String selectedGider = settings.giderKalemleri.isNotEmpty ? settings.giderKalemleri.first : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text('Yeni Gider Kaydı', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedArac,
                      items: settings.araclar.map((arac) {
                        return DropdownMenuItem(
                          value: arac,
                          child: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedArac = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Araç Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedGider,
                      items: settings.giderKalemleri.map((gider) {
                        return DropdownMenuItem(
                          value: gider,
                          child: Text(gider, style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGider = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Gider Kalemi',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tutarController.text.isNotEmpty) {
                    final data = Provider.of<DataProvider>(context, listen: false);
                    data.addGiderKaydi({
                      'tarih': Timestamp.fromDate(selectedDate),
                      'aracKodu': selectedArac,
                      'giderAdi': selectedGider,
                      'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gider kaydı başarıyla eklendi')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: child,
    );
  }

  void _showGiderKayitDuzenle(BuildContext context, Map<String, dynamic> kayit, int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);

    // Global index'i bul
    final globalIndex = data.giderKayitlari.indexWhere((k) => k['id'] == kayit['id']);

    String selectedArac = kayit['aracKodu'];
    String selectedGider = kayit['giderAdi'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController tutarController = TextEditingController(text: NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tutar']));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text('Gider Kaydını Düzenle', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedArac,
                      items: Provider.of<AppSettings>(context).araclar.map((arac) {
                        return DropdownMenuItem(
                          value: arac,
                          child: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedArac = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Araç Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedGider,
                      items: Provider.of<AppSettings>(context).giderKalemleri.map((gider) {
                        return DropdownMenuItem(
                          value: gider,
                          child: Text(gider, style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGider = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Gider Kalemi',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tutarController.text.isNotEmpty) {
                    if (globalIndex != -1) {
                      data.updateGiderKaydi(globalIndex, {
                        'tarih': Timestamp.fromDate(selectedDate),
                        'aracKodu': selectedArac,
                        'giderAdi': selectedGider,
                        'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gider kaydı başarıyla güncellendi')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }
}
// 7.2 Gider Ekleme/Düzenleme SONU ******************************************************************

// 7. BÖLÜM SONU ******************************************************************
// 8.1 CariSayfasi State Yönetimi ******************************************************************
class CariSayfasi extends StatefulWidget {
  @override
  _CariSayfasiState createState() => _CariSayfasiState();
}

class _CariSayfasiState extends State<CariSayfasi> {
  String _selectedCari = 'Tümü';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final settings = Provider.of<AppSettings>(context);

    // Kullanıcı bazlı filtreleme uygula
    List<Map<String, dynamic>> faturalar = data.getFilteredFaturaKayitlari(
        context);
    List<Map<String, dynamic>> tahsilatlar = data.getFilteredTahsilatKayitlari(
        context);

    if (_selectedCari != 'Tümü') {
      faturalar =
          faturalar.where((f) => f['cariAdi'] == _selectedCari).toList();
      tahsilatlar =
          tahsilatlar.where((t) => t['cariAdi'] == _selectedCari).toList();
    }

    if (_startDate != null && _endDate != null) {
      faturalar = faturalar.where((f) {
        final tarih = (f['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(_endDate!.add(Duration(days: 1))));
      }).toList();

      tahsilatlar = tahsilatlar.where((t) {
        final tarih = (t['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(_endDate!.add(Duration(days: 1))));
      }).toList();
    }

    double toplamFatura = faturalar.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
    double toplamTahsilat = tahsilatlar.fold(0, (sum, kayit) => sum + (kayit['tahsilatTutari'] ?? 0).toDouble());
    double bakiye = toplamFatura - toplamTahsilat;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cari Hesap', style: TextStyle(color: Colors.grey
            .shade800)),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.grey.shade800,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi
          if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Kullanıcı: ${settings.selectedUserForAdmin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: Icon(Icons.business, color: Colors.grey.shade700),
                title: Text('Cari Seçin',
                    style: TextStyle(color: Colors.grey.shade800)),
                subtitle: Text(_selectedCari,
                    style: TextStyle(color: Colors.grey.shade600)),
                trailing: Icon(
                    Icons.arrow_drop_down, color: Colors.grey.shade700),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        AlertDialog(
                          backgroundColor: Colors.amber.shade50,
                          title: Text('Cari Seçin', style: TextStyle(
                              color: Colors.grey.shade800)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text('TÜMÜ', style: TextStyle(
                                    color: Colors.grey.shade800)),
                                trailing: _selectedCari == 'Tümü'
                                    ? Icon(
                                    Icons.check, color: Colors.amber.shade700)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCari = 'Tümü';
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                              ...settings.cariler.map((cari) =>
                                  ListTile(
                                    title: Text(cari, style: TextStyle(
                                        color: Colors.grey.shade800)),
                                    trailing: _selectedCari == cari ? Icon(
                                        Icons.check,
                                        color: Colors.amber.shade700) : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedCari = cari;
                                      });
                                      Navigator.pop(context);
                                    },
                                  )).toList(),
                            ],
                          ),
                        ),
                  );
                },
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showFaturaEkle(context),
                    icon: Icon(Icons.receipt),
                    label: Text('FATURA OLUŞTUR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showTahsilatEkle(context),
                    icon: Icon(Icons.payment),
                    label: Text('TAHSİLAT GİR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: Icon(
                    Icons.calendar_today, color: Colors.grey.shade700),
                title: Text('Tarih Filtresi',
                    style: TextStyle(color: Colors.grey.shade800)),
                subtitle: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('dd.MM.yyyy').format(
                      _startDate!)} - ${DateFormat('dd.MM.yyyy').format(
                      _endDate!)}'
                      : 'Tüm Tarihler',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Icon(
                    Icons.arrow_drop_down, color: Colors.grey.shade700),
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    currentDate: DateTime.now(),
                    saveText: 'Tamam',
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.amber.shade700,
                            onPrimary: Colors.white,
                            surface: Colors.amber.shade50,
                            onSurface: Colors.grey.shade800,
                          ),
                          dialogBackgroundColor: Colors.amber.shade50,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                  }
                },
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _cariPdfOlustur(context),
              icon: Icon(Icons.picture_as_pdf),
              label: Text('CARİ RAPORU OLUŞTUR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 4,
                shadowColor: Colors.grey.shade800,
              ),
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.amber.shade100,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'FATURALAR',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: faturalar.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt, size: 48,
                                  color: Colors.grey.shade300),
                              SizedBox(height: 8),
                              Text(
                                'Fatura kaydı bulunmuyor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: faturalar.length,
                          itemBuilder: (context, index) {
                            final kayit = faturalar[index];
                            return _buildCariItem(kayit, true, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.amber.shade100,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'TAHSİLATLAR',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: tahsilatlar.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 48,
                                  color: Colors.grey.shade300),
                              SizedBox(height: 8),
                              Text(
                                'Tahsilat kaydı bulunmuyor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: tahsilatlar.length,
                          itemBuilder: (context, index) {
                            final kayit = tahsilatlar[index];
                            return _buildCariItem(kayit, false, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bakiye >= 0 ? Colors.amber.shade100 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: bakiye >= 0 ? Colors.amber.shade200 : Colors.red
                      .shade200,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedCari == 'Tümü' ? 'TOPLAM' : _selectedCari
                        .toUpperCase()} BAKİYE:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${NumberFormat.currency(
                        locale: 'tr_TR', symbol: '', decimalDigits: 2).format(
                        bakiye)} ₺',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: bakiye >= 0 ? Colors.grey.shade800 : Colors.red
                          .shade800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCariItem(Map<String, dynamic> kayit, bool isFatura, int index) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Container(
        height: 35,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${NumberFormat.currency(
                      locale: 'tr_TR', symbol: '', decimalDigits: 2).format(
                      isFatura ? kayit['tutar'] : kayit['tahsilatTutari'])} ₺',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isFatura ? Colors.grey.shade800 : Colors.grey
                        .shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 14),
                    onPressed: () =>
                    isFatura
                        ? _showFaturaDuzenle(context, kayit, index)
                        : _showTahsilatDuzenle(context, kayit, index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 14, color: Colors.red),
                    onPressed: () {
                      _showSilmeOnayDialog(context, () {
                        if (isFatura) {
                          final globalIndex = data.faturaKayitlari.indexWhere((
                              k) => k['id'] == kayit['id']);
                          if (globalIndex != -1) {
                            data.deleteFaturaKaydi(globalIndex);
                          }
                        } else {
                          final globalIndex = data.tahsilatKayitlari
                              .indexWhere((k) => k['id'] == kayit['id']);
                          if (globalIndex != -1) {
                            data.deleteTahsilatKaydi(globalIndex);
                          }
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Kayıt silindi')),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSilmeOnayDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text(
              "Silme Onayı", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("Bu kaydı silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text(
                  "İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

// 8.1 CariSayfasi State Yönetimi SONU ******************************************************************

// 8.2 Fatura İşlemleri ******************************************************************
  void _showFaturaEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedCari = settings.cariler.isNotEmpty
        ? settings.cariler.first
        : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController faturaNoController = TextEditingController();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text(
                'Yeni Fatura', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedCari,
                      items: settings.cariler.map((cari) {
                        return DropdownMenuItem(
                          value: cari,
                          child: Text(cari,
                              style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedCari = value!;
                      },
                      decoration: InputDecoration(
                        labelText: 'Cari Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: faturaNoController,
                      decoration: InputDecoration(
                        labelText: 'Fatura No',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih',
                          style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(
                          DateFormat('dd.MM.yyyy').format(selectedDate),
                          style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(
                          Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          selectedDate = picked;
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (faturaNoController.text.isNotEmpty &&
                      tutarController.text.isNotEmpty) {
                    final data = Provider.of<DataProvider>(
                        context, listen: false);
                    data.addFaturaKaydi({
                      'tarih': Timestamp.fromDate(selectedDate),
                      'cariAdi': selectedCari,
                      'faturaNo': faturaNoController.text,
                      'tutar': double.parse(
                          tutarController.text.replaceAll('.', '').replaceAll(
                              ',', '')),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fatura kaydı başarıyla eklendi')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Kaydet'),
              ),
            ],
          ),
    );
  }

  void _showTahsilatEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedCari = settings.cariler.isNotEmpty
        ? settings.cariler.first
        : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text(
                'Yeni Tahsilat', style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedCari,
                      items: settings.cariler.map((cari) {
                        return DropdownMenuItem(
                          value: cari,
                          child: Text(cari,
                              style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedCari = value!;
                      },
                      decoration: InputDecoration(
                        labelText: 'Cari Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih',
                          style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(
                          DateFormat('dd.MM.yyyy').format(selectedDate),
                          style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(
                          Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          selectedDate = picked;
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tahsilat Tutarı (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tutarController.text.isNotEmpty) {
                    final data = Provider.of<DataProvider>(
                        context, listen: false);
                    data.addTahsilatKaydi({
                      'tarih': Timestamp.fromDate(selectedDate),
                      'cariAdi': selectedCari,
                      'tahsilatTutari': double.parse(
                          tutarController.text.replaceAll('.', '').replaceAll(
                              ',', '')),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Tahsilat kaydı başarıyla eklendi')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Kaydet'),
              ),
            ],
          ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: child,
    );
  }

  void _showFaturaDuzenle(BuildContext context, Map<String, dynamic> kayit,
      int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);

    // Global index'i bul
    final globalIndex = data.faturaKayitlari.indexWhere((k) =>
    k['id'] == kayit['id']);

    String selectedCari = kayit['cariAdi'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController faturaNoController = TextEditingController(
        text: kayit['faturaNo']);
    TextEditingController tutarController = TextEditingController(
        text: NumberFormat.currency(
            locale: 'tr_TR', symbol: '', decimalDigits: 2).format(
            kayit['tutar']));

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Colors.amber.shade50,
            title: Text('Fatura Kaydını Düzenle',
                style: TextStyle(color: Colors.grey.shade800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputContainer(
                    child: DropdownButtonFormField<String>(
                      value: selectedCari,
                      items: Provider
                          .of<AppSettings>(context)
                          .cariler
                          .map((cari) {
                        return DropdownMenuItem(
                          value: cari,
                          child: Text(cari,
                              style: TextStyle(color: Colors.grey.shade800)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        selectedCari = value!;
                      },
                      decoration: InputDecoration(
                        labelText: 'Cari Seçin',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: faturaNoController,
                      decoration: InputDecoration(
                        labelText: 'Fatura No',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: ListTile(
                      title: Text('Tarih',
                          style: TextStyle(color: Colors.grey.shade800)),
                      subtitle: Text(
                          DateFormat('dd.MM.yyyy').format(selectedDate),
                          style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Icon(
                          Icons.calendar_today, color: Colors.grey.shade600),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.amber.shade700,
                                  onPrimary: Colors.white,
                                  surface: Colors.amber.shade50,
                                  onSurface: Colors.grey.shade800,
                                ),
                                dialogBackgroundColor: Colors.amber.shade50,
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          selectedDate = picked;
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildInputContainer(
                    child: TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        border: InputBorder.none,
                        suffixText: '₺',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'İptal', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (faturaNoController.text.isNotEmpty &&
                      tutarController.text.isNotEmpty) {
                    if (globalIndex != -1) {
                      data.updateFaturaKaydi(globalIndex, {
                        'tarih': Timestamp.fromDate(selectedDate),
                        'cariAdi': selectedCari,
                        'faturaNo': faturaNoController.text,
                        'tutar': double.parse(
                            tutarController.text.replaceAll('.', '').replaceAll(
                                ',', '')),
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                            'Fatura kaydı başarıyla güncellendi')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text('Güncelle'),
              ),
            ],
          ),
    );
  }

// 8.2 Fatura İşlemleri SONU ******************************************************************

// 8.3 Tahsilat İşlemleri ******************************************************************
  void _showTahsilatDuzenle(BuildContext context, Map<String, dynamic> kayit, int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);

    // Global index'i bul
    final globalIndex = data.tahsilatKayitlari.indexWhere((k) => k['id'] == kayit['id']);

    String selectedCari = kayit['cariAdi'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController tutarController = TextEditingController(text: NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tahsilatTutari']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text('Tahsilat Kaydını Düzenle', style: TextStyle(color: Colors.grey.shade800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputContainer(
                child: DropdownButtonFormField<String>(
                  value: selectedCari,
                  items: Provider.of<AppSettings>(context).cariler.map((cari) {
                    return DropdownMenuItem(
                      value: cari,
                      child: Text(cari, style: TextStyle(color: Colors.grey.shade800)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedCari = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Cari Seçin',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: ListTile(
                  title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.amber.shade700,
                              onPrimary: Colors.white,
                              surface: Colors.amber.shade50,
                              onSurface: Colors.grey.shade800,
                            ),
                            dialogBackgroundColor: Colors.amber.shade50,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tahsilat Tutarı (₺)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    suffixText: '₺',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tutarController.text.isNotEmpty) {
                if (globalIndex != -1) {
                  data.updateTahsilatKaydi(globalIndex, {
                    'tarih': Timestamp.fromDate(selectedDate),
                    'cariAdi': selectedCari,
                    'tahsilatTutari': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tahsilat kaydı başarıyla güncellendi')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _cariPdfOlustur(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final settings = Provider.of<AppSettings>(context, listen: false);
      final data = Provider.of<DataProvider>(context, listen: false);

      // Kullanıcı bazlı filtreleme uygula
      List<Map<String, dynamic>> faturalar = data.getFilteredFaturaKayitlari(context);
      List<Map<String, dynamic>> tahsilatlar = data.getFilteredTahsilatKayitlari(context);

      if (_selectedCari != 'Tümü') {
        faturalar = faturalar.where((f) => f['cariAdi'] == _selectedCari).toList();
        tahsilatlar = tahsilatlar.where((t) => t['cariAdi'] == _selectedCari).toList();
      }

      if (_startDate != null && _endDate != null) {
        faturalar = faturalar.where((f) {
          final tarih = (f['tarih'] as Timestamp).toDate();
          return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              tarih.isBefore(_endDate!.add(Duration(days: 1))));
        }).toList();

        tahsilatlar = tahsilatlar.where((t) {
          final tarih = (t['tarih'] as Timestamp).toDate();
          return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              tarih.isBefore(_endDate!.add(Duration(days: 1))));
        }).toList();
      }

      // BAKİYE HESAPLAMASI - PDF için
      double toplamFatura = faturalar.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
      double toplamTahsilat = tahsilatlar.fold(0, (sum, kayit) => sum + (kayit['tahsilatTutari'] ?? 0).toDouble());
      double bakiye = toplamFatura - toplamTahsilat;

      // PDF başlık
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CARİ HESAP RAPORU',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Cari: ${_selectedCari}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Tarih Aralığı: ${_startDate != null && _endDate != null
                      ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}'
                      : 'Tüm Tarihler'}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
                  pw.Text(
                    'Kullanıcı: ${settings.selectedUserForAdmin}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 20),

                // Faturalar bölümü
                pw.Text(
                  'FATURALAR',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                faturalar.isEmpty
                    ? pw.Text('Fatura kaydı bulunmuyor', style: pw.TextStyle(fontSize: 12))
                    : pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Tarih', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Fatura No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Tutar (₺)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...faturalar.map((fatura) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Text(DateFormat('dd.MM.yyyy').format((fatura['tarih'] as Timestamp).toDate()), style: pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Text(fatura['faturaNo'] ?? '', style: pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Text(NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(fatura['tutar'] ?? 0), style: pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Tahsilatlar bölümü
                pw.Text(
                  'TAHSİLATLAR',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                tahsilatlar.isEmpty
                    ? pw.Text('Tahsilat kaydı bulunmuyor', style: pw.TextStyle(fontSize: 12))
                    : pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Tarih', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Tutar (₺)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...tahsilatlar.map((tahsilat) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Text(DateFormat('dd.MM.yyyy').format((tahsilat['tarih'] as Timestamp).toDate()), style: pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(4),
                            child: pw.Text(NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(tahsilat['tahsilatTutari'] ?? 0), style: pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Özet bölümü
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    color: PdfColors.amber100,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${_selectedCari == 'Tümü' ? 'TOPLAM' : _selectedCari.toUpperCase()} BAKİYE:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.Text(
                        '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(bakiye)} ₺',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: bakiye >= 0 ? PdfColors.black : PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // PDF'i paylaş - Printing paketini kullan
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'cari-raporu-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata: $e')),
      );
    }
  }
}
// 8.3 Tahsilat İşlemleri SONU ******************************************************************
// 8. BÖLÜM SONU ******************************************************************
// 9.1 PersonelSayfasi State Yönetimi ******************************************************************
class PersonelSayfasi extends StatefulWidget {
  @override
  _PersonelSayfasiState createState() => _PersonelSayfasiState();
}

class _PersonelSayfasiState extends State<PersonelSayfasi> {
  String _selectedPersonel = 'Tümü';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final settings = Provider.of<AppSettings>(context);

    // Kullanıcı bazlı filtreleme uygula
    List<Map<String, dynamic>> tahakkuklar = data.getFilteredMaasTahakkuklari(context);
    List<Map<String, dynamic>> odemeler = data.getFilteredMaasOdemeleri(context);

    if (_selectedPersonel != 'Tümü') {
      tahakkuklar = tahakkuklar.where((t) => t['personel'] == _selectedPersonel).toList();
      odemeler = odemeler.where((o) => o['personel'] == _selectedPersonel).toList();
    }

    if (_startDate != null && _endDate != null) {
      tahakkuklar = tahakkuklar.where((t) {
        final tarih = (t['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(_endDate!.add(Duration(days: 1))));
      }).toList();

      odemeler = odemeler.where((o) {
        final tarih = (o['tarih'] as Timestamp).toDate();
        return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
            tarih.isBefore(_endDate!.add(Duration(days: 1))));
      }).toList();
    }

    double toplamTahakkuk = tahakkuklar.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
    double toplamOdeme = odemeler.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
    double bakiye = toplamTahakkuk - toplamOdeme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Personel İşlemleri', style: TextStyle(color: Colors.grey.shade800)),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.grey.shade800,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi
          if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Kullanıcı: ${settings.selectedUserForAdmin}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: Icon(Icons.people, color: Colors.grey.shade700),
                title: Text('Personel Seçin', style: TextStyle(color: Colors.grey.shade800)),
                subtitle: Text(_selectedPersonel, style: TextStyle(color: Colors.grey.shade600)),
                trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.amber.shade50,
                      title: Text('Personel Seçin', style: TextStyle(color: Colors.grey.shade800)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text('TÜMÜ', style: TextStyle(color: Colors.grey.shade800)),
                            trailing: _selectedPersonel == 'Tümü' ? Icon(Icons.check, color: Colors.amber.shade700) : null,
                            onTap: () {
                              setState(() {
                                _selectedPersonel = 'Tümü';
                              });
                              Navigator.pop(context);
                            },
                          ),
                          ...settings.personeller.map((personel) => ListTile(
                            title: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                            trailing: _selectedPersonel == personel ? Icon(Icons.check, color: Colors.amber.shade700) : null,
                            onTap: () {
                              setState(() {
                                _selectedPersonel = personel;
                              });
                              Navigator.pop(context);
                            },
                          )).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showMaasTahakkukEkle(context),
                    icon: Icon(Icons.add_chart),
                    label: Text('MAAŞ TAHAKKUKU'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showMaasOdemeEkle(context),
                    icon: Icon(Icons.payment),
                    label: Text('MAAŞ ÖDEME'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 4,
                      shadowColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                title: Text('Tarih Filtresi', style: TextStyle(color: Colors.grey.shade800)),
                subtitle: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}'
                      : 'Tüm Tarihler',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    currentDate: DateTime.now(),
                    saveText: 'Tamam',
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.amber.shade700,
                            onPrimary: Colors.white,
                            surface: Colors.amber.shade50,
                            onSurface: Colors.grey.shade800,
                          ),
                          dialogBackgroundColor: Colors.amber.shade50,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                  }
                },
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _personelPdfOlustur(context),
              icon: Icon(Icons.picture_as_pdf),
              label: Text('PERSONEL RAPORU OLUŞTUR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
                shadowColor: Colors.grey.shade800,
              ),
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.amber.shade100,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MAAŞ TAHAKKUKLARI',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: tahakkuklar.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_chart, size: 48, color: Colors.grey.shade300),
                              SizedBox(height: 8),
                              Text(
                                'Maaş tahakkuku bulunmuyor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: tahakkuklar.length,
                          itemBuilder: (context, index) {
                            final kayit = tahakkuklar[index];
                            return _buildPersonelItem(kayit, true, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.amber.shade100,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'MAAŞ ÖDEMELERİ',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: odemeler.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 48, color: Colors.grey.shade300),
                              SizedBox(height: 8),
                              Text(
                                'Maaş ödemesi bulunmuyor',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: odemeler.length,
                          itemBuilder: (context, index) {
                            final kayit = odemeler[index];
                            return _buildPersonelItem(kayit, false, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bakiye >= 0 ? Colors.amber.shade100 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: bakiye >= 0 ? Colors.amber.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedPersonel == 'Tümü' ? 'TOPLAM' : _selectedPersonel.toUpperCase()} BAKİYE:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(bakiye)} ₺',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: bakiye >= 0 ? Colors.grey.shade800 : Colors.red.shade800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonelItem(Map<String, dynamic> kayit, bool isTahakkuk, int index) {
    final data = Provider.of<DataProvider>(context, listen: false);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Container(
        height: 35,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tutar'])} ₺',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 14),
                    onPressed: () => isTahakkuk
                        ? _showMaasTahakkukDuzenle(context, kayit, index)
                        : _showMaasOdemeDuzenle(context, kayit, index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 14, color: Colors.red),
                    onPressed: () {
                      _showSilmeOnayDialog(context, () {
                        if (isTahakkuk) {
                          final globalIndex = data.maasTahakkuklari.indexWhere((k) => k['id'] == kayit['id']);
                          if (globalIndex != -1) {
                            data.deleteMaasTahakkuku(globalIndex);
                          }
                        } else {
                          final globalIndex = data.maasOdemeleri.indexWhere((k) => k['id'] == kayit['id']);
                          if (globalIndex != -1) {
                            data.deleteMaasOdeme(globalIndex);
                          }
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Kayıt silindi')),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSilmeOnayDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Silme Onayı", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("Bu kaydı silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }
// 9.1 PersonelSayfasi State Yönetimi SONU ******************************************************************

// 9.2 Maaş Tahakkuk İşlemleri ******************************************************************
  void _showMaasTahakkukEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedPersonel = settings.personeller.isNotEmpty ? settings.personeller.first : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text('Maaş Tahakkuku Ekle', style: TextStyle(color: Colors.grey.shade800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputContainer(
                child: DropdownButtonFormField<String>(
                  value: selectedPersonel,
                  items: settings.personeller.map((personel) {
                    return DropdownMenuItem(
                      value: personel,
                      child: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedPersonel = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Personel Seçin',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: ListTile(
                  title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.amber.shade700,
                              onPrimary: Colors.white,
                              surface: Colors.amber.shade50,
                              onSurface: Colors.grey.shade800,
                            ),
                            dialogBackgroundColor: Colors.amber.shade50,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tahakkuk Tutarı (₺)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    suffixText: '₺',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tutarController.text.isNotEmpty) {
                final data = Provider.of<DataProvider>(context, listen: false);
                data.addMaasTahakkuku({
                  'tarih': Timestamp.fromDate(selectedDate),
                  'personel': selectedPersonel,
                  'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Maaş tahakkuku başarıyla eklendi')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showMaasOdemeEkle(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String selectedPersonel = settings.personeller.isNotEmpty ? settings.personeller.first : '';
    DateTime selectedDate = DateTime.now();
    TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text('Maaş Ödemesi Ekle', style: TextStyle(color: Colors.grey.shade800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputContainer(
                child: DropdownButtonFormField<String>(
                  value: selectedPersonel,
                  items: settings.personeller.map((personel) {
                    return DropdownMenuItem(
                      value: personel,
                      child: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedPersonel = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Personel Seçin',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: ListTile(
                  title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.amber.shade700,
                              onPrimary: Colors.white,
                              surface: Colors.amber.shade50,
                              onSurface: Colors.grey.shade800,
                            ),
                            dialogBackgroundColor: Colors.amber.shade50,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Ödeme Tutarı (₺)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    suffixText: '₺',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tutarController.text.isNotEmpty) {
                final data = Provider.of<DataProvider>(context, listen: false);
                data.addMaasOdeme({
                  'tarih': Timestamp.fromDate(selectedDate),
                  'personel': selectedPersonel,
                  'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Maaş ödemesi başarıyla eklendi')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: child,
    );
  }

  void _showMaasTahakkukDuzenle(BuildContext context, Map<String, dynamic> kayit, int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);

    // Global index'i bul
    final globalIndex = data.maasTahakkuklari.indexWhere((k) => k['id'] == kayit['id']);

    String selectedPersonel = kayit['personel'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController tutarController = TextEditingController(text: NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tutar']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text('Maaş Tahakkukunu Düzenle', style: TextStyle(color: Colors.grey.shade800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputContainer(
                child: DropdownButtonFormField<String>(
                  value: selectedPersonel,
                  items: Provider.of<AppSettings>(context).personeller.map((personel) {
                    return DropdownMenuItem(
                      value: personel,
                      child: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedPersonel = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Personel Seçin',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: ListTile(
                  title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.amber.shade700,
                              onPrimary: Colors.white,
                              surface: Colors.amber.shade50,
                              onSurface: Colors.grey.shade800,
                            ),
                            dialogBackgroundColor: Colors.amber.shade50,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tahakkuk Tutarı (₺)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    suffixText: '₺',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tutarController.text.isNotEmpty) {
                if (globalIndex != -1) {
                  data.updateMaasTahakkuku(globalIndex, {
                    'tarih': Timestamp.fromDate(selectedDate),
                    'personel': selectedPersonel,
                    'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Maaş tahakkuku başarıyla güncellendi')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Güncelle'),
          ),
        ],
      ),
    );
  }
// 9.2 Maaş Tahakkuk İşlemleri SONU ******************************************************************

// 9.3 Maaş Ödeme İşlemleri ******************************************************************
  void _showMaasOdemeDuzenle(BuildContext context, Map<String, dynamic> kayit, int filteredIndex) {
    final data = Provider.of<DataProvider>(context, listen: false);

    // Global index'i bul
    final globalIndex = data.maasOdemeleri.indexWhere((k) => k['id'] == kayit['id']);

    String selectedPersonel = kayit['personel'];
    DateTime selectedDate = (kayit['tarih'] as Timestamp).toDate();
    TextEditingController tutarController = TextEditingController(text: NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(kayit['tutar']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text('Maaş Ödemesini Düzenle', style: TextStyle(color: Colors.grey.shade800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInputContainer(
                child: DropdownButtonFormField<String>(
                  value: selectedPersonel,
                  items: Provider.of<AppSettings>(context).personeller.map((personel) {
                    return DropdownMenuItem(
                      value: personel,
                      child: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedPersonel = value!;
                  },
                  decoration: InputDecoration(
                    labelText: 'Personel Seçin',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: ListTile(
                  title: Text('Tarih', style: TextStyle(color: Colors.grey.shade800)),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: TextStyle(color: Colors.grey.shade600)),
                  trailing: Icon(Icons.calendar_today, color: Colors.grey.shade600),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.amber.shade700,
                              onPrimary: Colors.white,
                              surface: Colors.amber.shade50,
                              onSurface: Colors.grey.shade800,
                            ),
                            dialogBackgroundColor: Colors.amber.shade50,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputContainer(
                child: TextField(
                  controller: tutarController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Ödeme Tutarı (₺)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    border: InputBorder.none,
                    suffixText: '₺',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              if (tutarController.text.isNotEmpty) {
                if (globalIndex != -1) {
                  data.updateMaasOdeme(globalIndex, {
                    'tarih': Timestamp.fromDate(selectedDate),
                    'personel': selectedPersonel,
                    'tutar': double.parse(tutarController.text.replaceAll('.', '').replaceAll(',', '')),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Maaş ödemesi başarıyla güncellendi')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _personelPdfOlustur(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final settings = Provider.of<AppSettings>(context, listen: false);
      final data = Provider.of<DataProvider>(context, listen: false);

      // Kullanıcı bazlı filtreleme uygula
      List<Map<String, dynamic>> tahakkuklar = data.getFilteredMaasTahakkuklari(context);
      List<Map<String, dynamic>> odemeler = data.getFilteredMaasOdemeleri(context);

      if (_selectedPersonel != 'Tümü') {
        tahakkuklar = tahakkuklar.where((t) => t['personel'] == _selectedPersonel).toList();
        odemeler = odemeler.where((o) => o['personel'] == _selectedPersonel).toList();
      }

      if (_startDate != null && _endDate != null) {
        tahakkuklar = tahakkuklar.where((t) {
          final tarih = (t['tarih'] as Timestamp).toDate();
          return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              tarih.isBefore(_endDate!.add(Duration(days: 1))));
        }).toList();

        odemeler = odemeler.where((o) {
          final tarih = (o['tarih'] as Timestamp).toDate();
          return (tarih.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              tarih.isBefore(_endDate!.add(Duration(days: 1))));
        }).toList();
      }

      double toplamTahakkuk = tahakkuklar.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
      double toplamOdeme = odemeler.fold(0, (sum, kayit) => sum + (kayit['tutar'] ?? 0).toDouble());
      double bakiye = toplamTahakkuk - toplamOdeme;

      String baslik = _selectedPersonel == 'Tümü'
          ? '${settings.raporBasligi} Tüm Personeller ${_startDate != null && _endDate != null ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} / ${DateFormat('dd.MM.yyyy').format(_endDate!)}' : 'Tüm Tarihler'} Personel Maaş Ekstresi'
          : '${settings.raporBasligi} ${_selectedPersonel} ${_startDate != null && _endDate != null ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} / ${DateFormat('dd.MM.yyyy').format(_endDate!)}' : 'Tüm Tarihler'} Personel Maaş Ekstresi';

      // Kullanıcı bilgisi ekle
      if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty) {
        baslik += ' - Kullanıcı: ${settings.selectedUserForAdmin}';
      } else if (!settings.isAdmin) {
        baslik += ' - Kullanıcı: ${settings.currentUser}';
      }

      final font = await PdfGoogleFonts.nunitoSansRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  baslik,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: font),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(color: PdfColors.amber100),
                          child: pw.Text(
                            'MAAŞ TAHAKKUKLARI',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                          ),
                        ),
                        pw.Table.fromTextArray(
                          border: pw.TableBorder.all(),
                          headers: ['Tarih', 'Personel', 'Tutar'],
                          data: tahakkuklar.map((kayit) {
                            final dateFormat = DateFormat('dd.MM.yyyy');
                            final moneyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2);
                            return [
                              dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                              kayit['personel'],
                              '${moneyFormat.format(kayit['tutar'] ?? 0)} ₺',
                            ];
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(color: PdfColors.amber100),
                          child: pw.Text(
                            'MAAŞ ÖDEMELERİ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                          ),
                        ),
                        pw.Table.fromTextArray(
                          border: pw.TableBorder.all(),
                          headers: ['Tarih', 'Personel', 'Tutar'],
                          data: odemeler.map((kayit) {
                            final dateFormat = DateFormat('dd.MM.yyyy');
                            final moneyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2);
                            return [
                              dateFormat.format((kayit['tarih'] as Timestamp).toDate()),
                              kayit['personel'],
                              '${moneyFormat.format(kayit['tutar'] ?? 0)} ₺',
                            ];
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: bakiye >= 0 ? PdfColors.amber50 : PdfColors.red50,
                  border: pw.Border.all(),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'PERSONEL BAKİYE:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      '${NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 2).format(bakiye)} ₺',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        color: bakiye >= 0 ? PdfColors.black : PdfColors.red,
                        font: font,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'personel-raporu-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel PDF raporu başarıyla oluşturuldu ve paylaşıma hazır!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata: $e')),
      );
    }
  }
}
// 9.3 Maaş Ödeme İşlemleri SONU ******************************************************************

// 9. BÖLÜM SONU ******************************************************************
// 10.1 AyarlarSayfasi State Yönetimi ******************************************************************
class AyarlarSayfasi extends StatefulWidget {
  @override
  _AyarlarSayfasiState createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  final TextEditingController _yeniAracController = TextEditingController();
  final TextEditingController _yeniGiderController = TextEditingController();
  final TextEditingController _yeniPersonelController = TextEditingController();
  final TextEditingController _yeniCariController = TextEditingController();
  final TextEditingController _kdvController = TextEditingController();
  final TextEditingController _tevkifatController = TextEditingController();
  final TextEditingController _birimFiyatController = TextEditingController();
  final TextEditingController _raporBaslikController = TextEditingController();
  final TextEditingController _yeniKullaniciAdiController = TextEditingController();
  final TextEditingController _yeniKullaniciSifreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  void _loadInitialSettings() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<AppSettings>(context, listen: false);
      _kdvController.text = settings.kdvOrani.toString();
      _tevkifatController.text = (settings.tevkifatOrani * 100).toString();
      _birimFiyatController.text = settings.tonajBirimFiyat.toString();
      _raporBaslikController.text = settings.raporBasligi;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ayarlar', style: TextStyle(color: Colors.grey.shade800)),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.grey.shade800,
      ),
      body: Consumer<AppSettings>(
        builder: (context, settings, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı bilgisi
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.amber.shade700),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.isAdmin ? 'ADMİN' : 'KULLANICI',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              settings.isAdmin ? 'admin' : settings.currentUser,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (settings.isAdmin && settings.selectedUserForAdmin.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Seçili: ${settings.selectedUserForAdmin}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (settings.isAdmin) ...[
                  _buildAyarlarKarti(
                    'Kullanıcı Yönetimi',
                    Icon(Icons.people, color: Colors.amber.shade700),
                    [
                      // YENİ KULLANICI EKLEME ALANI
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _yeniKullaniciAdiController,
                                  decoration: InputDecoration(
                                    labelText: 'Kullanıcı Adı',
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(color: Colors.amber.shade700),
                                    ),
                                    fillColor: Colors.amber.shade50,
                                    filled: true,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _yeniKullaniciSifreController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Şifre',
                                    labelStyle: TextStyle(color: Colors.grey.shade700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(color: Colors.amber.shade700),
                                    ),
                                    fillColor: Colors.amber.shade50,
                                    filled: true,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  if (_yeniKullaniciAdiController.text.isNotEmpty &&
                                      _yeniKullaniciSifreController.text.isNotEmpty) {
                                    settings.addKullanici(
                                        _yeniKullaniciAdiController.text.trim(),
                                        _yeniKullaniciSifreController.text.trim()
                                    );

                                    _yeniKullaniciAdiController.clear();
                                    _yeniKullaniciSifreController.clear();
                                    FocusScope.of(context).unfocus();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Kullanıcı başarıyla eklendi'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Lütfen kullanıcı adı ve şifre giriniz!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Ekle'),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),

                          // KULLANICI LİSTESİ
                          if (settings.kullanicilar.isEmpty)
                            Container(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Henüz kullanıcı bulunmuyor',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: settings.kullanicilar.keys.map((kullanici) {
                                return Chip(
                                  label: Text(
                                      kullanici,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.bold,
                                      )
                                  ),
                                  backgroundColor: Colors.amber.shade100,
                                  deleteIcon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                                  onDeleted: () {
                                    _showKullaniciSilmeOnayDialog(context, kullanici, settings);
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],

                _buildAyarlarKarti(
                  'Tevkifat Ayarları',
                  Icon(Icons.account_balance, color: Colors.amber.shade700),
                  [
                    SwitchListTile(
                      title: Text('Tevkifat Uygulansın', style: TextStyle(color: Colors.grey.shade800)),
                      value: settings.tevkifatUygulansin,
                      onChanged: (value) {
                        settings.updateSettings(tevkifatUygulansin: value);
                      },
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _tevkifatController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tevkifat Oranı (%)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Mevcut: %${(settings.tevkifatOrani * 100).toInt()}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                        fillColor: Colors.amber.shade50,
                        filled: true,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_tevkifatController.text.isNotEmpty) {
                          final tevkifat = double.tryParse(_tevkifatController.text);
                          if (tevkifat != null) {
                            settings.updateSettings(tevkifatOrani: tevkifat / 100);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tevkifat oranı başarıyla güncellendi')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Tevkifat Oranını Güncelle'),
                    ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Araç Listesi',
                  Icon(Icons.directions_car, color: Colors.amber.shade700),
                  [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yeniAracController,
                            decoration: InputDecoration(
                              labelText: 'Yeni Araç Kodu',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              hintText: 'Örn: 47',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.amber.shade700),
                              ),
                              fillColor: Colors.amber.shade50,
                              filled: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_yeniAracController.text.isNotEmpty) {
                              settings.addArac(_yeniAracController.text);
                              _yeniAracController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Araç başarıyla eklendi')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Ekle'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    if (settings.araclar.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Henüz araç bulunmuyor',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: settings.araclar.map((arac) {
                          return Chip(
                            label: Text('Araç $arac', style: TextStyle(color: Colors.grey.shade800)),
                            backgroundColor: Colors.amber.shade100,
                            deleteIcon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                            onDeleted: () {
                              _showAracSilmeOnayDialog(context, arac, settings);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Gider Kalemleri',
                  Icon(Icons.money_off, color: Colors.amber.shade700),
                  [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yeniGiderController,
                            decoration: InputDecoration(
                              labelText: 'Yeni Gider Kalemi',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              hintText: 'Örn: YAKIT',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.amber.shade700),
                              ),
                              fillColor: Colors.amber.shade50,
                              filled: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_yeniGiderController.text.isNotEmpty) {
                              settings.addGiderKalemi(_yeniGiderController.text);
                              _yeniGiderController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gider kalemi başarıyla eklendi')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Ekle'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    if (settings.giderKalemleri.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Henüz gider kalemi bulunmuyor',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: settings.giderKalemleri.map((gider) {
                          return Chip(
                            label: Text(gider, style: TextStyle(color: Colors.grey.shade800)),
                            backgroundColor: Colors.amber.shade100,
                            deleteIcon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                            onDeleted: () {
                              _showGiderSilmeOnayDialog(context, gider, settings);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Personel Listesi',
                  Icon(Icons.people, color: Colors.amber.shade700),
                  [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yeniPersonelController,
                            decoration: InputDecoration(
                              labelText: 'Yeni Personel',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              hintText: 'Örn: ŞOFÖR AHMET',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.amber.shade700),
                              ),
                              fillColor: Colors.amber.shade50,
                              filled: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_yeniPersonelController.text.isNotEmpty) {
                              settings.addPersonel(_yeniPersonelController.text);
                              _yeniPersonelController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Personel başarıyla eklendi')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Ekle'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    if (settings.personeller.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Henüz personel bulunmuyor',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: settings.personeller.map((personel) {
                          return Chip(
                            label: Text(personel, style: TextStyle(color: Colors.grey.shade800)),
                            backgroundColor: Colors.amber.shade100,
                            deleteIcon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                            onDeleted: () {
                              _showPersonelSilmeOnayDialog(context, personel, settings);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Cari Listesi',
                  Icon(Icons.business, color: Colors.amber.shade700),
                  [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yeniCariController,
                            decoration: InputDecoration(
                              labelText: 'Yeni Cari',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              hintText: 'Örn: ÇAN LİNYİTLERİ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade400),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.amber.shade700),
                              ),
                              fillColor: Colors.amber.shade50,
                              filled: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_yeniCariController.text.isNotEmpty) {
                              settings.addCari(_yeniCariController.text);
                              _yeniCariController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Cari başarıyla eklendi')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Ekle'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    if (settings.cariler.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Henüz cari bulunmuyor',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: settings.cariler.map((cari) {
                          return Chip(
                            label: Text(cari, style: TextStyle(color: Colors.grey.shade800)),
                            backgroundColor: Colors.amber.shade100,
                            deleteIcon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                            onDeleted: () {
                              _showCariSilmeOnayDialog(context, cari, settings);
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),

                _buildAyarlarKarti(
                  'KDV Oranı',
                  Icon(Icons.percent, color: Colors.amber.shade700),
                  [
                    TextField(
                      controller: _kdvController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'KDV Oranı (%)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Mevcut: %${settings.kdvOrani}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                        fillColor: Colors.amber.shade50,
                        filled: true,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_kdvController.text.isNotEmpty) {
                          final kdv = double.tryParse(_kdvController.text);
                          if (kdv != null) {
                            settings.updateSettings(kdvOrani: kdv);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('KDV oranı başarıyla güncellendi')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('KDV Oranını Güncelle'),
                    ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Tonaj Birim Fiyat',
                  Icon(Icons.attach_money, color: Colors.amber.shade700),
                  [
                    TextField(
                      controller: _birimFiyatController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tonaj Birim Fiyat (₺)',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Mevcut: ${settings.tonajBirimFiyat} ₺',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                        fillColor: Colors.amber.shade50,
                        filled: true,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_birimFiyatController.text.isNotEmpty) {
                          final birimFiyat = double.tryParse(_birimFiyatController.text);
                          if (birimFiyat != null) {
                            settings.updateSettings(tonajBirimFiyat: birimFiyat);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Birim fiyat başarıyla güncellendi')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Birim Fiyatı Güncelle'),
                    ),
                  ],
                ),

                _buildAyarlarKarti(
                  'Rapor Başlığı',
                  Icon(Icons.title, color: Colors.amber.shade700),
                  [
                    TextField(
                      controller: _raporBaslikController,
                      decoration: InputDecoration(
                        labelText: 'Rapor Başlığı',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Mevcut: ${settings.raporBasligi}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.amber.shade700),
                        ),
                        fillColor: Colors.amber.shade50,
                        filled: true,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_raporBaslikController.text.isNotEmpty) {
                          settings.updateSettings(raporBasligi: _raporBaslikController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rapor başlığı başarıyla güncellendi')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Başlığı Güncelle'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAyarlarKarti(String title, Icon icon, List<Widget> children) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.amber.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showKullaniciSilmeOnayDialog(BuildContext context, String kullanici, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Kullanıcı Silme", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("'$kullanici' kullanıcısını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                settings.removeKullanici(kullanici);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kullanıcı silindi')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showAracSilmeOnayDialog(BuildContext context, String arac, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Araç Silme", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("'Araç $arac' silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                settings.removeArac(arac);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Araç silindi')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showGiderSilmeOnayDialog(BuildContext context, String gider, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Gider Kalemi Silme", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("'$gider' gider kalemini silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                settings.removeGiderKalemi(gider);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gider kalemi silindi')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showPersonelSilmeOnayDialog(BuildContext context, String personel, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Personel Silme", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("'$personel' personelini silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                settings.removePersonel(personel);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Personel silindi')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showCariSilmeOnayDialog(BuildContext context, String cari, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.amber.shade50,
          title: Text("Cari Silme", style: TextStyle(color: Colors.grey.shade800)),
          content: Text("'$cari' carisini silmek istediğinizden emin misiniz?",
              style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(
              child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text("Sil"),
              onPressed: () {
                settings.removeCari(cari);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cari silindi')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
// 10.1 AyarlarSayfasi State Yönetimi SONU ******************************************************************

// 10.2 Kullanıcı Yönetimi ******************************************************************
Widget _buildAyarlarKarti(String title, Icon icon, List<Widget> children) {
  return Card(
    margin: EdgeInsets.only(bottom: 16),
    color: Colors.amber.shade50,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              icon,
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

void _showKullaniciSilmeOnayDialog(BuildContext context, String kullanici) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text("Kullanıcı Silme", style: TextStyle(color: Colors.grey.shade800)),
        content: Text("'$kullanici' kullanıcısını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(
            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text("Sil"),
            onPressed: () {
              final settings = Provider.of<AppSettings>(context, listen: false);
              settings.removeKullanici(kullanici);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kullanıcı silindi')),
              );
            },
          ),
        ],
      );
    },
  );
}

void _showAracSilmeOnayDialog(BuildContext context, String arac) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text("Araç Silme", style: TextStyle(color: Colors.grey.shade800)),
        content: Text("'Araç $arac' silmek istediğinizden emin misiniz?",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(
            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text("Sil"),
            onPressed: () {
              final settings = Provider.of<AppSettings>(context, listen: false);
              settings.removeArac(arac);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Araç silindi')),
              );
            },
          ),
        ],
      );
    },
  );
}

void _showGiderSilmeOnayDialog(BuildContext context, String gider) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text("Gider Kalemi Silme", style: TextStyle(color: Colors.grey.shade800)),
        content: Text("'$gider' gider kalemini silmek istediğinizden emin misiniz?",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(
            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text("Sil"),
            onPressed: () {
              final settings = Provider.of<AppSettings>(context, listen: false);
              settings.removeGiderKalemi(gider);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gider kalemi silindi')),
              );
            },
          ),
        ],
      );
    },
  );
}

void _showPersonelSilmeOnayDialog(BuildContext context, String personel) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text("Personel Silme", style: TextStyle(color: Colors.grey.shade800)),
        content: Text("'$personel' personelini silmek istediğinizden emin misiniz?",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(
            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text("Sil"),
            onPressed: () {
              final settings = Provider.of<AppSettings>(context, listen: false);
              settings.removePersonel(personel);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Personel silindi')),
              );
            },
          ),
        ],
      );
    },
  );
}

void _showCariSilmeOnayDialog(BuildContext context, String cari) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade50,
        title: Text("Cari Silme", style: TextStyle(color: Colors.grey.shade800)),
        content: Text("'$cari' carisini silmek istediğinizden emin misiniz?",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(
            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text("Sil"),
            onPressed: () {
              final settings = Provider.of<AppSettings>(context, listen: false);
              settings.removeCari(cari);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cari silindi')),
              );
            },
          ),
        ],
      );
    },
  );
}

// 10.2 Kullanıcı Yönetimi SONU ******************************************************************

// 10. BÖLÜM SONU ******************************************************************
//emrah
