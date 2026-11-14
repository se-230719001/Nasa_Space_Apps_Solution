# MoonMinds — Game Systems Design (Kaynak ve Sistem Etkileşimleri)

**Kapsam:** Kaynaklar, binalar, araştırma ve keşif sistemlerinin birbirini nasıl etkilediği.
**Hedef kitle:** 7–12 yaş · Single Player · 3D Ay kolonisi yönetimi
**Zaman birimi:** *Gün*. Oyun tur tabanlıdır (9 Kings gibi): oyuncu kararlarını verir, **END DAY** ile günü bitirir ve gün sonu raporu alır. **Her 5 günde bir** önceden duyurulan bir problem gelir. İnşa ve seviye yükseltme **anında** gerçekleşir; bedeli yalnızca malzemedir.

Temel oyun döngüsü:
**İnşa Et → Geliştir → Araştır → Koloni koşullarını iyileştir → Hangarı geliştir → Uzay aracı üret → Keşfe çık → Bilim puanı ve Araştırma Kartı kazan**

Kavramlar (bütün tablolarda aynı anlamda kullanılır):

| Kavram | Anlamı | Örnek |
|---|---|---|
| **Stok** | Şu an elde olan miktar | Su tankında 120 L |
| **Üretim** | Bir günde üretilen miktar | Sera: +12 gıda/gün |
| **Tüketim** | Bir günde harcanan miktar | 4 kişi: −4 O₂/gün |
| **Kapasite** | Depolanabilen veya üretilebilen en fazla miktar | Batarya 120 birim |
| **Verimlilik** | Aynı girdiyle alınan çıktı oranı | Geri dönüşüm %75 |
| **Tek seferlik tüketim** | İnşa, geliştirme, uzay aracı üretimi | 30 malzeme |
| **Sürekli tüketim** | Çalışan sistemlerin her gün harcadığı | Elektroliz: −15 enerji/gün |

---

## A. Nihai Kaynak Etkileşim Tablosu

"Doğrudan" = eylem değeri hemen değiştirir. "Dolaylı" = başka bir sistem üzerinden, gecikmeli etkiler.

### A.1 Nüfus ve Sağlık

| Sistem / Eylem | Artan Değer | Azalan Değer | Etkinin Türü | Koşul / Kısıtlama |
|---|---|---|---|---|
| Nüfus artar (+1 kişi) | O₂, su, gıda tüketimi; CO₂ üretimi; barınma ve Sağlık Merkezi ihtiyacı | — | Doğrudan | Yeni kişi yalnızca **boş barınma kapasitesi** varsa ve sağlık ≥ %60 iken gelir |
| Egzersiz programı açılır | Sağlık hedefi (+5) | Su (+%10) ve gıda (+%10) tüketimi artar | Doğrudan | Sağlık Merkezi Lv. 1 gerekir; sağlık hedefini aşamaz |
| Yeterli uyku (Uyku programı) | Sağlık hedefi (+5), iyileşme hızı | — | Doğrudan | Sağlık Merkezi Lv. 2 gerekir; barınma dolu değilse çalışır |
| Gıda yetersiz | — | Sağlık hedefi düşer (eksik oranı kadar) | Doğrudan | Stok 0 ise uygulanır |
| Su yetersiz | — | Sağlık hedefi düşer | Doğrudan | Stok 0 ise uygulanır |
| Oksijen yetersiz | — | Sağlık hedefi hızla düşer | Doğrudan | En öncelikli uyarı |
| CO₂ çok yüksek (> 70) | — | Sağlık hedefi düşer | Doğrudan | Eşik altında etkisi yok |
| Radyasyon maruziyeti artar | Sağlık riski | Sağlık hedefi düşer | Doğrudan | Yalnızca **korunmayan** kişiler etkilenir |

**Sağlık modeli (ihtiyaç karşılama):** Sağlık sınırsız artmaz. Her gün bir **hedef sağlık** hesaplanır ve gerçek sağlık bu hedefe günde en fazla %10 yaklaşır.

`Hedef = Taban (Sağlık Merkezi seviyesine göre 70 / 80 / 88 / 94 / 100) × en düşük ihtiyaç karşılama oranı (O₂, su, gıda) − radyasyon cezası − CO₂ cezası + uyku/egzersiz bonusu (tavanı aşamaz)`

*Oynanışa etkisi:* Oyuncu "kaynak yığarak" sağlığı yükseltemez. Sağlığı artırmanın yolu ihtiyaçları karşılamak ve Sağlık Merkezi'ni geliştirmektir.

### A.2 Oksijen, CO₂, Su ve Fotosentez

| Sistem / Eylem | Artan Değer | Azalan Değer | Etkinin Türü | Koşul / Kısıtlama |
|---|---|---|---|---|
| Elektroliz (Yaşam Destek) çalışır | O₂ | Su, enerji | Doğrudan | Su ve enerji yetmezse verim oransal düşer. **CO₂'yi azaltmaz** |
| CO₂ filtresi çalışır | — | CO₂, enerji | Doğrudan | Ayrı bir sistemdir; açık/kapalı yapılabilir |
| Fotosentez (Sera) | O₂, gıda | CO₂, su, enerji (aydınlatma) | Doğrudan | **Işık + su + CO₂ birlikte** gerekir. Biri eksikse hepsi düşer |
| CO₂ çok düşük (< 20) | — | Fotosentez verimi | Dolaylı | CO₂ 20'nin altındaysa bitki büyümesi yavaşlar |
| CO₂ uygun (30–60) | Fotosentez verimi (en çok %130) | — | Dolaylı | 60'ın üstünde ek fayda yok, 70'te sağlık riski başlar |
| Sera kapasitesi artar (Lv) | Gıda ve O₂ üretimi | Daha çok su, enerji, CO₂ ihtiyacı | Doğrudan | Seviye başına ihtiyaç da artar |
| Su geri dönüşümü gelişir | Kullanılabilir su (net kayıp azalır) | Enerji | Doğrudan | Geri dönüşüm %60 / 75 / 85 / 95; %100 olamaz |
| Su arıtma enerji alamaz | — | Geri dönüşüm oranı | Dolaylı | Enerji payı kadar çalışır |

### A.3 Enerji ve Batarya

| Sistem / Eylem | Artan Değer | Azalan Değer | Etkinin Türü | Koşul / Kısıtlama |
|---|---|---|---|---|
| Enerji Merkezi inşa / Lv | Enerji **üretim kapasitesi** | Malzeme (tek seferlik) | Doğrudan | Üretim = kapasite × güneş ışığı |
| Güneş ışığı artar / azalır | Panel üretimi (aynı yönde) | — | Doğrudan | Ay gecesi ve toz: üretim %40–60'a iner |
| Üretim > tüketim | Batarya **doluluğu** | — | Doğrudan | Batarya **kapasitesini** aşamaz; fazlası boşa gider |
| Batarya geliştirilir | Depolama **kapasitesi** | Malzeme | Doğrudan | **Batarya enerji üretmez**, yalnızca depolar |
| Tüketim > üretim | — | Batarya doluluğu | Doğrudan | Batarya boşalınca enerji paylaşımı devreye girer |
| Enerji yetersiz | — | Sistemlerin çalışma oranı | Dolaylı | **Öncelik:** Yaşam Destek → Su Arıtma → Sera → Sağlık → Rad. Lab → Hangar. Aynı öncelikte oransal paylaşım |

### A.4 Radyasyon ve Koruma

| Sistem / Eylem | Artan Değer | Azalan Değer | Etkinin Türü | Koşul / Kısıtlama |
|---|---|---|---|---|
| Güneş fırtınası | Ortam radyasyonu (2–3 gün) | Güneş ışığı az değişmez; panel güvenliği için üretim %70 | Doğrudan | Rad. Lab varsa **önceden uyarı** gelir (Lv1: 1 gün, Lv2: 3 gün) |
| Maruziyet artar | — | Korunmayan kişilerin sağlık hedefi | Doğrudan | Stoklar (su, gıda, O₂) **azalmaz** |
| Radyasyon sığınağı (Rad. Lab Lv3) | Korunan kişi sayısı | — | Doğrudan | Fırtına sırasında sığınaktaki kişiler maruz kalmaz |
| Kalkan geliştirmesi (Araştırma) | Koruma oranı | Malzeme | Doğrudan | Kalıcıdır |
| Astronot kıyafeti (Rad. Lab Lv4) | Keşif görevlerinde koruma | Malzeme | Doğrudan | Uzak görevlerin sağlık riskini azaltır |
| Fırtınada korunmasız sera | — | O gün bitki büyümesi (%−20) | Dolaylı | Stok değil, **o günkü üretim** etkilenir |

### A.5 Hangar ve Keşif

| Sistem / Eylem | Artan Değer | Azalan Değer | Etkinin Türü | Koşul / Kısıtlama |
|---|---|---|---|---|
| Hangar Lv artar | Üretilebilecek uzay aracı türleri | Malzeme | Doğrudan | Lv tek başına maden bulma şansını **artırmaz** |
| Uzay aracı üretilir | Keşif kapasitesi (araç sayısı) | Malzeme (tek seferlik), üretim süresi | Doğrudan | Aynı anda en fazla Hangar Lv kadar araç |
| Menzil geliştirilir (Araştırma) | Ulaşılabilir hedefler | Bilim puanı | Doğrudan | Uzak hedef = daha uzun süre + daha çok yakıt/O₂/gıda |
| Bilimsel tarama ekipmanı (Araştırma) | Değerli maden tespit şansı | Bilim puanı | Doğrudan | Maden tespiti **sensörlere** bağlıdır |
| Keşif tamamlanır | Bilim puanı, Araştırma Kartı, malzeme | — | Doğrudan | Görev süresi bitince |
| Değerli maden tespit edilir | Yeni toplama görevi / araştırma | — | Dolaylı | Yeni bir görev seçeneği açılır |
| Keşfe çıkılır | — | Enerji (yakıt), O₂ ve gıda (görev süresi × mürettebat) | Doğrudan | Kalkıştan önce yeterli stok gerekir |

---

## B. Bina Bazlı Etkileşimler

Her bina 4 seviyelidir. **Lv1** temel üretim ve takip, **Lv2** verimlilik, **Lv3** gelişmiş teknoloji, **Lv4** otomasyon. Her seviye sayıdan fazlasını yapar, **yeni bir oyun seçeneği açar**.

### B.1 Yaşam Destek Merkezi *(oyun başında Lv1 kurulu)*

| | |
|---|---|
| **Tüketir** | Enerji (elektroliz 15/gün, CO₂ filtresi 6/gün), su (elektroliz 6/gün) |
| **Üretir / korur** | O₂ (12/gün); CO₂ temizleme (8/gün); barınma (4 kişi/Lv) |
| **Etkileşim** | Su Arıtma'dan su alır, Enerji Merkezi'ne en yüksek öncelikle bağlıdır, Sera ile birlikte CO₂ dengesini kurar |
| **Çalışma koşulu** | Enerji + su |

| Lv | Etkisi | Açılan seçenek |
|---|---|---|
| 1 | Elektroliz + CO₂ filtresi, 4 kişilik barınma | Hava paneli (O₂ ve CO₂ değerleri) |
| 2 | O₂ üretimi +%40, barınma 8 | CO₂ filtresini aç/kapat (enerji tasarrufu) |
| 3 | CO₂ filtresi +%50, barınma 12 | Hava kalitesi sensörü: CO₂ uyarısını önceden verir |
| 4 | Barınma 16, **Sabatier** sistemi | CO₂'den su geri kazanımı (döngü kapanır) |

### B.2 Sera

| | |
|---|---|
| **Tüketir** | Enerji (aydınlatma 12/gün), su (10/gün), CO₂ (5/gün) |
| **Üretir** | Gıda (13/gün), O₂ (4/gün) |
| **Etkileşim** | Su Arıtma (su), Enerji Merkezi (ışık), Yaşam Destek (CO₂ dengesi) |
| **Çalışma koşulu** | Işık + su + CO₂; en düşük olan verimi belirler |

| Lv | Etkisi | Açılan seçenek |
|---|---|---|
| 1 | Temel üretim | Bitki durumu göstergesi |
| 2 | Üretim +%35, ihtiyaç +%25 | **Damla sulama:** su ihtiyacı −%30 (Araştırma Kartı) |
| 3 | Üretim +%70, ihtiyaç +%45 | **LED spektrum:** enerji −%25 |
| 4 | Üretim +%100, ihtiyaç +%60 | **Otomatik hidroponik:** CO₂ düşükken bile verim korunur |

### B.3 Enerji Merkezi

| | |
|---|---|
| **Tüketir** | — (yalnızca inşa ve geliştirme malzemesi) |
| **Üretir / korur** | Enerji üretim kapasitesi (28/gün/Lv × güneş ışığı), batarya kapasitesi |
| **Etkileşim** | Bütün binaları besler; enerji yetmezse öncelik sırası uygulanır |
| **Çalışma koşulu** | Güneş ışığı (gece/toz/fırtınada düşük) |

| Lv | Etkisi | Açılan seçenek |
|---|---|---|
| 1 | 28 enerji/gün, batarya +60 | Enerji paneli: üretim, tüketim, doluluk ayrı gösterilir |
| 2 | Güneşi izleyen paneller (+%25) | Toz temizleme görevi |
| 3 | Batarya +120 | Gece planlaması: bataryayı geceye ayırma |
| 4 | **Akıllı şebeke** | Öncelik sırasını oyuncu değiştirebilir |

### B.4 Su Arıtma Merkezi

| | |
|---|---|
| **Tüketir** | Enerji (8/gün) |
| **Üretir / korur** | Geri dönüştürülen su; Lv3'ten sonra buzdan su (+10/gün) |
| **Etkileşim** | Yaşam Destek, Sera ve mürettebatın kullandığı suyu geri kazanır |
| **Çalışma koşulu** | Enerji |

| Lv | Geri dönüşüm | Açılan seçenek |
|---|---|---|
| 0 (bina yok) | %50 (temel filtre) | — |
| 1 | %60 | Su döngüsü şeması |
| 2 | %75 | Gri su ayrıştırma |
| 3 | %85, buz işleme +10/gün | Kutup krateri buz görevleri |
| 4 | %95 | Kapalı döngü |

### B.5 Sağlık Merkezi

| | |
|---|---|
| **Tüketir** | Enerji (5/gün); egzersiz programı açıkken su ve gıda +%10 |
| **Üretir / korur** | Sağlık hedef tavanı; uyku ve egzersiz programları |
| **Etkileşim** | Bütün kaynakların "yeterli mi" bilgisini sağlık hedefine çevirir |
| **Çalışma koşulu** | Enerji. Nüfus kapasitesini aşarsa bonuslar yarıya iner |

| Lv | Sağlık tavanı | Kapasite | Açılan seçenek |
|---|---|---|---|
| 0 | 70 | — | — |
| 1 | 80 | 6 kişi | **Egzersiz programı** (aç/kapat) |
| 2 | 88 | 10 kişi | **Uyku programı** |
| 3 | 94 | 14 kişi | Beslenme takibi (gıda verimliliği +%10) |
| 4 | 100 | 20 kişi | Revir: fırtına sonrası hızlı iyileşme |

### B.6 Radyasyon Laboratuvarı

| | |
|---|---|
| **Tüketir** | Enerji (6/gün) |
| **Üretir / korur** | Fırtına uyarısı, koruma kapasitesi, bilim puanı (1/gün) |
| **Etkileşim** | Sağlık hedefini korur; Hangar görevlerine kıyafet koruması verir |
| **Çalışma koşulu** | Enerji |

| Lv | Etkisi | Açılan seçenek |
|---|---|---|
| 1 | Radyasyon ölçümü, fırtına uyarısı 1 gün önce | Radyasyon detay paneli |
| 2 | Uyarı 3 gün önce, koruma +%10 | Hazırlık önerileri |
| 3 | **Sığınak:** tüm nüfus korunur | Fırtınada "sığınağa geç" seçeneği |
| 4 | Gelişmiş kıyafet | Keşifte radyasyon riski −%50 |

### B.7 Hangar *(oyun başında Lv1 kurulu)*

| | |
|---|---|
| **Tüketir** | Malzeme (araç üretimi); görev başına enerji (yakıt), O₂, gıda |
| **Üretir** | Uzay aracı; görev dönüşünde bilim puanı, Araştırma Kartı, malzeme |
| **Etkileşim** | Araştırma (menzil, sensör), Rad. Lab (kıyafet), Yaşam Destek (görev O₂'si) |
| **Çalışma koşulu** | Boş araç + yeterli stok |

| Lv | Araç | Ulaşılan hedef |
|---|---|---|
| 1 | Ay gezgini | Ay kraterleri (1–2 gün) |
| 2 | Mekik | Mars (6 gün) |
| 3 | Derin uzay aracı | Europa, Psyche asteroidi (10 gün) |
| 4 | Bilim laboratuvarlı araç | Bütün görevlerde ek Araştırma Kartı |

---

## C. Düzeltilmesi veya Kaldırılması Gereken İlişkiler

| İlişki | Sorun | Gerekçe | Alternatif |
|---|---|---|---|
| Elektroliz CO₂'yi azaltır | **Bilimsel hata** | Elektroliz suyu H₂ ve O₂'ye ayırır, CO₂ ile ilgisi yoktur | Ayrı **CO₂ filtresi** (enerji tüketir) |
| Radyasyon su, gıda ve O₂ stoğunu azaltır | **Bilimsel hata** | Radyasyon depolanmış suyu ya da oksijeni "yok etmez" | Yalnızca canlıları etkiler: korunmasız kişiler ve o günkü bitki büyümesi |
| Sağlık, kaynaklar arttıkça sürekli artar | **Denge sorunu** | İhtiyaç karşılandıktan sonra fazla gıda sağlığı artırmaz | Hedef sağlık modeli ve seviye tavanı |
| Batarya enerji üretir | **Kavram hatası** | Batarya enerji depolar | Üretim, tüketim ve depolama ayrı göstergeler |
| Hangar seviyesi maden bulma şansını artırır | **Mantık hatası** | Maden tespiti sensörlerle yapılır | Bilimsel tarama ekipmanı (Araştırma) |
| CO₂ arttıkça fotosentez sınırsız artar | **Basitleştirme hatası** | Bitkilerin bir doyum noktası vardır; aşırı CO₂ insanlara zararlıdır | Verim tavanı %130; 70 üstünde sağlık riski |
| Başarısız görevde can veya malzeme kaybı | **Pedagojik sorun** | Çocuk cezadan değil, açıklamadan öğrenir | "Ne oldu, neden oldu, ne deneyebilirsin" geri bildirimi; acil durumda Dünya'dan destek |
| Yıl (tur) sayacı ve 30 yıllık süre | **Gereksiz karmaşıklık** | Kaynak akışını günlük düşünmek daha sezgisel | Gün tabanlı tur (END DAY), her 5 günde bir duyurulan problem; hedefler görev listesinde |
| İnşaat bekleme süreleri | **Gereksiz bekleme** | Çocuk, kararının sonucunu hemen görmeli | İnşa ve yükseltme anında; denge malzeme maliyetiyle kurulur |
| Her tur kart seçimi | **Tekrar eden mekanik** | BUILD / RESEARCH / EXPLORE döngüsüyle çakışıyor | Kartlar yalnızca **Araştırma Kartı** olarak keşiften gelir |

---

## D. Eklenmesi Gereken İlişkiler

| İlişki | Sınıf | Oynanışa somut etkisi |
|---|---|---|
| Nüfus ↑ → O₂, su, gıda tüketimi ↑, CO₂ üretimi ↑ | **Zorunlu** | Koloni büyümesi planlama gerektirir |
| Barınma kapasitesi (Yaşam Destek Lv) nüfusu sınırlar | **Zorunlu** | Büyümek için önce barınma kurulmalı |
| Enerji paylaşım önceliği | **Zorunlu** | Kıtlıkta oyuncu neyin önce kapandığını görür ve öğrenir |
| Fotosentez = ışık + su + CO₂ (en düşük olan belirler) | **Zorunlu** | "Liebig'in minimum yasası" sezgisel olarak öğretilir |
| CO₂ filtresi ayrı sistem | **Zorunlu** | Elektroliz / filtre / bitki ayrımı netleşir |
| Batarya: kapasite ve doluluk ayrı | **Zorunlu** | Gece planlaması mümkün olur |
| Fırtına erken uyarısı (Rad. Lab) | **Faydalı** | Ceza yerine hazırlık fırsatı |
| Görev kaynakları (O₂, gıda, yakıt) gidiş süresiyle orantılı | **Faydalı** | Uzak hedefler gerçek bir karar olur |
| Sensör seviyesi → maden tespiti | **Faydalı** | Araştırma ile keşif birbirine bağlanır |
| Koloni büyüdükçe koruma alanı (kubbe) genişler | **Faydalı** | Görsel ilerleme hissi ve yeni inşa alanı |
| Sabatier: CO₂ + H₂ → su + metan | **İsteğe bağlı** (Yaşam Destek Lv4) | Döngüyü kapatmayı öğretir |
| Ay gecesi döngüsü (güneş ışığı dalgalanması) | **İsteğe bağlı** | Batarya kullanımını öğretir |
| İletişim gecikmesi (uzak görevlerde rapor gecikir) | **İsteğe bağlı** | Uzay mesafesi kavramı |

---

## E. Örnek Oyun Senaryoları

### Senaryo 1 — Kolonide oksijen azalıyor
- **Durum:** Nüfus 4'ten 6'ya çıktı. Fanusun kenarı yeşilden maviye döndü, O₂ simgesinin halkası sarardı.
- **Oyuncunun kararı:** O₂ simgesine dokunur ve "Goes DOWN with: her kişi nefes alır" satırını görür. Yaşam Destek Merkezi'ni Lv2'ye geliştirir ve ek olarak bir sera kurar.
- **Sistem etkisi:** Elektroliz O₂'yi artırır ama daha çok su ve enerji harcar. Sera O₂ üretir ve CO₂'yi azaltır.
- **Geri bildirim (maskot):** "Elektroliz suyu ikiye ayırıyor: hidrojen ve oksijen. Bitkiler de havadaki CO₂'yi oksijene çeviriyor. İkisini birlikte kullanınca daha az enerji harcıyoruz!"

### Senaryo 2 — Enerji yetersizliği nedeniyle sera üretimi düşüyor
- **Durum:** Ay gecesi başladı, paneller %50 üretiyor. Batarya boşalınca enerji paylaşımı devreye girdi; sera ihtiyacının yalnızca %40'ını alabiliyor.
- **Oyuncunun kararı:** Enerji simgesini açar ve öncelik sırasını görür (Yaşam Destek önce, sera sonra). Enerji Merkezi'ne batarya geliştirmesi yapar.
- **Sistem etkisi:** Bir sonraki gece batarya sera ışıklarını besler, gıda üretimi düşmez.
- **Geri bildirim:** "Gece güneş yok, paneller az çalışıyor. Batarya gündüz biriktirdiğimiz enerjiyi gece kullanmamızı sağlar. Ama dikkat: batarya enerji yapmaz, sadece saklar!"

### Senaryo 3 — Radyasyon uyarısı alan oyuncu kolonisini korumaya çalışıyor
- **Durum:** Radyasyon Lab Lv2, 3 gün önceden güneş fırtınası uyarısı verdi.
- **Oyuncunun kararı:** Laboratuvarı Lv3'e (sığınak) yükseltir ve yolda olan keşif görevini erken çağırmaz; Rad. Lab Lv4 kıyafeti olmadığı için yeni görev başlatmaz.
- **Sistem etkisi:** Fırtına boyunca sığınaktaki kişilerin sağlığı etkilenmez. Su, gıda ve O₂ stokları değişmez; yalnızca seranın o günkü büyümesi biraz yavaşlar.
- **Geri bildirim:** "Radyasyon depodaki suyu bozmaz, ama vücudumuza zarar verebilir. Kalın duvarlar ve Ay toprağı bizi korur. Erken uyarı sayesinde hazırdık!"

---

## F. Nihai Tasarım Önerisi

### F.1 Model özeti
1. **Beş ana gösterge:** Sağlık, Gıda, Su, Enerji, Oksijen. Her biri Stok + Üretim − Tüketim ile hesaplanır.
2. **Paylaşım kuralı:** Enerji ve su yetmediğinde öncelik sırasına göre dağıtılır, aynı öncelikte oransal paylaşılır. Bir bina aldığı pay kadar verimle çalışır.
3. **Hedef sağlık:** İhtiyaç karşılama oranı belirler, bina seviyesi tavanı belirler; sınırsız artış yoktur.
4. **Ceza yok, açıklama var:** Kaynak biterse sağlık hedefi düşer, maskot sebebi ve çözümü anlatır. Sağlık %25'in altına inerse Dünya'dan acil destek gelir ve neden geldiği açıklanır.
5. **Büyüme:** Bina ve nüfus arttıkça fanus genişler, yeni inşa alanı açılır.
6. **Keşif döngüsü:** Hangar → araç → görev → bilim puanı + Araştırma Kartı → yeni geliştirmeler.

### F.2 Nerede ne gösterilir

| Gösterge | Ana ekran (üst bar) | Bina / detay sayfası | Araştırma / Hangar sayfası |
|---|---|---|---|
| Sağlık, Gıda, Su, Enerji, Oksijen | ✅ Simge + renkli halka | Üretim / tüketim ayrıntısı | — |
| CO₂ seviyesi | Fanusun buğusu (görsel) | Yaşam Destek, Sera | — |
| Radyasyon seviyesi | Yalnızca fırtına uyarısı | Radyasyon Lab | — |
| Batarya kapasitesi / doluluk | Enerji detayında | Enerji Merkezi | — |
| Nüfus / barınma | Üst bar detayında | Yaşam Destek, Sağlık Merkezi | — |
| Bilim puanı, malzeme | ✅ Küçük sayaç | — | Araştırma |
| Uzay araçları, keşif kapasitesi | — | Hangar | Hangar |
| Araştırma Kartları | — | — | Araştırma |

**Üst bar davranışı:** Ekranın üst ortasında sabit durur ve yalnızca beş simge gösterir. Dokununca açılır: simgeler alt alta dizilir, her birinin yanında değer, günlük değişim ve kısa açıklama görünür.

**Alt bar:** **BUILD** (inşa ve geliştirme) · **RESEARCH** (bilim puanı ve kartlar) · **EXPLORE** (Hangar) · **END DAY** (günü bitir, raporu gör).

**Problem takvimi:** Ekranın üstünde bir sonraki problem ve kalan gün her zaman görünür (ör. "5. gün: Ay toz fırtınası · 3 gün sonra"). Problem kartı; ne olacağını, güvenli olmak için hangi göstergenin hangi değerde olması gerektiğini, nasıl hazırlanılacağını ve iyi/kötü sonuç örneklerini gösterir. Sıralama: toz fırtınası → sera zararlıları → güneş fırtınası → yeni mürettebat → su sızıntısı → CO₂ filtresi arızası → uzun Ay gecesi; ikinci turda daha zordur.

**Rehberlik:** Oyun başında robot 8 adımlık bir eğitimle oyun dengesini ve döngüyü anlatır. Sol alttaki **TAKE HINT** düğmesi o anki en önemli adımı söyler: yaklaşan problem, en zayıf gösterge ya da sıradaki hedef. Her hedef iyi ve kötü bir örnekle birlikte gösterilir.

**Bina görünümü:** Her seviye binaya yeni parçalar ekler (ek kubbe, tank, anten, sığınak, Sabatier kulesi), böylece gelişim gözle görülür.
