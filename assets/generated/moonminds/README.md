# MoonMinds — yeni üretilen assetler

asset_prompts.md temel alınarak yerleşik image_gen aracıyla üretildi. API anahtarı veya ayrı API/CLI kurulumu kullanılmadı.

- 19 arayüz ikonu, 6 bina, 3 maskot pozu, 1 logo: toplam 29 ayrı PNG.
- 28 kare görsel 1254×1254; logo 2048×768. Kareler MD’deki en az 1024 px koşulunu karşılar; büyük boyut küçültülmeden korundu.
- Tüm dosyalar gerçek alfa kanallı RGBA PNG. Çözünürlük, dosya listesi, şeffaflık ve kaynak kopyası doğrulandı.
- Maskotun diğer pozlarında ilk maskot karakter referansı olarak kullanıldı. İkonlarda ilk sağlık ikonu stil referansı olarak kullanıldı.
- Güneş panelinin gereksiz üs ekleyen ilk sürümü ve boş kutunun lekeli ilk sürümü yerine düzeltilmiş sonuçlar seçildi.

## Üretim kayıtları

- prompts.json: 29 asset için ana stil kurallarıyla birleştirilmiş promptlar.
- generation_manifest.json: üretilen dosyaların repo içindeki göreli yolları.
- validation.json: dosya başına boyut, alfa kontrolü ve SHA-256 kaydı.

Mevcut assets/sprites dosyaları ve oyun kodu değiştirilmedi. Bu set henüz oyuna bağlanmadı. Bina PNG’leri arayüz görselleridir; 3D modelleri değiştirmezler.
