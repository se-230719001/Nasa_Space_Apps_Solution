# MoonMinds — tutarlı oyun mimarisi

## Amaç ve model sınırı

MoonMinds, 7–12 yaş oyuncuya Ay üssünü ayakta tutmak için güç, su, gıda, oksijen ve radyasyon arasında seçim yaptırır. NASA Space Apps 2026 “Build a Junior Astronaut Mission Trainer” hedefindeki yaşam desteği, güç, koruma ve gıda üretimi kararlarını kısa görevlerle öğretir.

Bu bir **eğitim oyunu simülasyonudur**, gerçek görev tasarım aracı değildir. Kaynak çubukları 0–100 arası oyun stoğu gösterir; bunlar kWh, litre veya kilogram değildir. Bina akışları aynı ölçekli oyun puanları/görev günü cinsindendir. NASA verisi çevre koşulunu (ör. aydınlanma/gölge takvimi) belirleyebilir; oyundaki panel verimi, bitki verimi ve sağlık etkisi açıkça oyun kalibrasyonu olarak kalır.

## Mimari sınırlar

- `scenes/core/outpost_simulation.gd`: tek doğruluk kaynağı; stok, kurulum, seviye, görev, günlük akış ve tahmin hesapları.
- `scenes/core/nasa_environment_data.gd`: NASA verisini doğrulanmış senaryo girdisine dönüştürecek adaptör sınırı. Canlı indirme bu aşamada yoktur.
- HUD: simülasyonun sonuçlarını gösterir ve karar önizlemesini sunar; kendi kaynak katsayısı veya ikinci bir sağlık hesabı tutmamalıdır.
- 3D dünya: simülasyonda onaylanan kurulu modüllerin görsel karşılığıdır.

Ana sahne başlangıçta Habitat, SolarArray ve WaterTank gösteriyor. Simülasyon başlangıcı da aynı üç binayı seviye 1 olarak kaydeder. Mevcut HUD'daki kalp barı geçici olarak en düşük kaynak barından türetiliyor; simülasyonun `crew_health` değeriyle henüz bağlı değil. UI entegrasyonunda kalp gerçek ekip sağlığına bağlanmalı; düşük kaynak uyarısı ilgili kaynak barında kalmalıdır.

## Oyuncunun gördüğü kaynaklar ve girdiler

| Veri | Oyun anlamı | Oyuncuya gösterim |
|---|---|---|
| Power, water, food, oxygen | Depoda kalan 0–100 oyun puanı | HUD çubuğu; tam sayıya yuvarlanır |
| Build kits | Bina/upgrade için taşınan parça paketi; başlangıç 18, üst sınır 30 | Sadece Build/Upgrade kartında “parça” olarak |
| Crew health | 0–100 ekip durumu; ihtiyaç açığı ve radyasyon etkisinden azalır | Kalp barı + metin |
| Sunlight | 0–1 günlük aydınlanma faktörü | Gün kartı: “Güneş güçlü / orta / az” |
| Radiation | Senaryonun günlük radyasyon baskısı, oyun puanı | Görev kartı ve kalkan önizlemesi |
| Science samples | Explore ile elde edilen araştırma puanı | Search kartında örnek sayısı |
| Day | Bir Search veya Explore turu bir görev günüdür | Üst şeritte “Gün 1” |

Parça maliyeti ile güç deposu artık aynı şey değildir: kurulum parça paketi harcar; elektrik yalnızca çalışan sistemlere gider. Stok barı hiçbir zaman üretim hızı diye sunulmaz.

## Başlangıç durumu

- Ekip: 2 kişi.
- Stoklar: Power 70, Water 65, Food 45, Oxygen 80.
- Build kits: 18 / 30.
- Crew health: 100.
- Kurulu: Habitat L1, Solar L1, Water Tank L1.
- Açık planlar: Greenhouse ve temel üs modülleri.
- İlk uzaktan gözlemden 1 Science sample: oyuncu Explore'a erişmek için önce Search'te Rover planını açabilir.

Bu başlangıç, mevcut `main.tscn` içindeki üç prosedürel binayla eşleşir. Solar L1 tam güneşte günde en çok 24 güç puanı üretir. Habitat L1'in zorunlu güç talebi 4 puan/gündür. Water Tank ekibin kullandığı suyun bir kısmını geri döndürür; suyu yoktan üretmez.

## Tek günlük matematik

Simülasyon gün başına bir kez, aynı sırayla çalışır:

1. **Solar üretim:** `üretilen güç = solar seviye kapasitesi × sunlight`. Önce üretim o günkü yüke gider; kalan güç depoya eklenir. Depo 100'ü aşarsa artan kısım `wasted_power` olarak raporlanır.
2. **Zorunlu yaşam desteği:** Habitat gücü önce karşılanır. Ardından ekip su, gıda ve oksijen talep eder. Depodaki miktar talebe yetmiyorsa eksik miktar açıkça kaydedilir; stok negatif olmaz.
3. **İsteğe bağlı makineler:** Water Tank geri kazanımı, Greenhouse ve Shield kalan güçten pay alır. Toplam güç yetmiyorsa isteğe bağlı makineler aynı oranda yavaşlar. Bu, çocuk için tek anlaşılır kuraldır: “Güç azsa makineler yavaşlar; yaşam desteği önce gelir.”
4. **Girdi-çıktı bağı:** Sera çıktısı şu üç koşulun en düşüğüne göre azalır: ışık, sera için kalan su, makinelerin alabildiği güç. Sera su/güç olmadan yiyecek veya oksijen üretemez. Water Tank yalnızca ekibin gerçekten kullandığı suyun belirli yüzdesini, çalışacak gücü varsa geri kazanır.
5. **Kalkan ve sağlık:** Shield koruması da güç payı kadar uygulanır. Sağlık kaybı = en büyük yaşam desteği açığının oranı × 10 (yukarı yuvarla) + kalkan sonrası günlük radyasyon 2'yi aşıyorsa aşan miktar. Kayıp en fazla mevcut sağlıktan düşer.
6. **Taşma ve rapor:** Power, food ve oxygen kapasiteyi aşarsa taşan değer raporlanır. Tur raporu üretilen güç, boşa giden güç, karşılanmayan ekip ihtiyacı, geri kazanılan su, üretilen gıda/oksijen ve sağlık değişimini verir.

Formül düzeyinde, sera için:

`ışık_sınırı = sunlight`

`su_sınırı = min(1, eldeki_su / sera_su_ihtiyacı)`

`sera_talep_oranı = min(ışık_sınırı, su_sınırı)`

`makine_güç_oranı = min(1, kalan_güç / isteğe_bağlı_makinelerin_toplam_güç_talebi)`

`sera_çalışma_oranı = sera_talep_oranı × makine_güç_oranı`

`sera_gıdası = seviye_gıda_kapasitesi × sera_çalışma_oranı`

Aynı oranla sera su kullanır ve oksijen üretir. Bütün değerler tam sayıya yuvarlanarak çocuk arayüzünde gösterilebilir; hesap içinde küsurat korunur.

## Bina profilleri ve seviyeler

Her modül türünden bu prototipte bir tane bulunur; L1–L3 seviyeleri vardır. İnşa/upgrade parça kiti tüketir. Yeni performans bir sonraki görev gününde devreye girer. Önizleme, mevcut durumla bir sonraki günü simüle eder; bina kartı tek başına teorik üretim değil **üs genelindeki tahmini değişimi** gösterir.

| Bina | L1 | L2 | L3 | Ödünleşim |
|---|---|---|---|---|
| Habitat | Zorunlu güç 4/gün | 3/gün | 2/gün | Kit yatırımı, her gün daha az yaşam desteği gücü |
| SolarArray | En çok +24 güç/gün × güneş | +32 × güneş | +40 × güneş | Karanlıkta üretim yine düşer; parça kiti gerekir |
| Greenhouse | 8 güç + 6 su harcar; en çok +12 gıda, +3 oksijen/gün | 10 güç + 7 su; +17 gıda, +4 oksijen | 12 güç + 8 su; +22 gıda, +5 oksijen | Yüksek seviye daha çok ürün verir, daha çok girdi ister |
| WaterTank / geri kazanım | Kullanılan ekip suyunun %50'sini geri alır; en çok 2 güç/gün | %65; en çok 3 güç | %80; en çok 4 güç | Daha az net su kaybı için elektrik kullanır |
| IceDrill | Günde +6 su; en çok 10 güç/gün | +8 su; 12 güç | +10 su; 14 güç | Tek gerçek su kaynağı; az güneşte sera ile güç için yarışır |
| Shield | 2 radyasyon puanı azaltır; en çok 3 güç/gün | 4 puan; 4 güç | 6 puan; 5 güç | Daha fazla koruma, daha fazla elektrik talebi |
| Rover | Keşif başına 8 güç, 3 su, 2 oksijen; 1 Science | 7 güç, 3 su, 2 oksijen; 2 Science | 6 güç, 2 su, 1 oksijen; 3 Science | Daha verimli keşif için önceden kit harcanır |

**Kit bedeli:** Sera 6, IceDrill 6, Shield 8, Rover 8; seviye yükseltme L1→L2 için 4, L2→L3 için 6 kit. Başlangıç kitleri tüm yapıları ve bütün yükseltmeleri aynı anda karşılamaz; oyuncu hedefe göre seçim yapar. Shield'i araştırma ile açınca 8 kitlik bir görev paketi gelir. Kit stoğu 30'u aşmaz; taşan kit ödülü `kit_overflow` olarak raporlanır.

Solar L1/L2/L3 üretimi, güneş ışığı ile çarpılır. Sera gücü ve suyu verilmediğinde tam ürün çıkarması mümkün değildir. WaterTank geri kazanımı yalnızca ekip tarafından gerçekten harcanmış suya uygulanır. Shield ilk seviyede radyasyonu sıfırlamaz. Bu kurallar modül açıklamasıyla simülasyonun aynı şeyi söylemesini sağlar.

## Görev sonu: kazanma ve kaybetme

- **Kaybetme:** Ekip sağlığı 0'a inerse görev biter. Kart, son günün en büyük açığını (su, gıda, oksijen) ya da radyasyonu neden olarak gösterir ve çözüm yolunu adlandırır.
- **Kazanma (Faz 0 görevi):** `OutpostSimulation.GOALS` sırasıyla tamamlanınca: Sera kur → Rover planını araştır → Rover kur → ilk keşif. Ekip hayatta olmalıdır.
- Hedef ve sonuç hesabı simülasyondadır (`goals_done`, `outcome`); HUD yalnızca gösterir. Faz 1'de her bölüm kendi hedef ve senaryosunu veri olarak taşıyacak.

## Search ve Explore — bağlı görev döngüsü

### Search

Search, uzaktan gözlem ve bilim örnekleriyle plan/teknoloji açar. İlk görev brifingindeki 1 bilim örneği **Rover Blueprint** araştırmasını açar: 1 sample + 2 mevcut güç, sonuçta Rover yapım planı açılır. Search bir görev günü ilerletir; gün sonu yaşam desteği yine hesaplanır.

Rover ile Explore tamamlanınca her gezi 1–3 Science sample verir. Bir sample ve 3 güç harcayan **Radiation Map** araştırması Shield planını açar ve 8 kitlik görev kargosunu getirir. Araştırmalar tek seferliktir; aynı ödül tekrar alınamaz.

### Explore

Explore, Rover varsa bir saha gezisi başlatır. Onaydan önce o seviye için gereken güç, su ve oksijen ile beklenen Science ödülü görünür. Rover dönüşte buz da getirir (L1/L2/L3: +6/+7/+8 su); keşif böylece hayatta kalmaya da katkı verir. Onayda bu kaynaklar anında düşer ve o görev günü ilerler. NASA/yerel senaryo koşulları o günün güneşlenmesini ve radyasyon puanını belirler. Geri dönülen bulgu Search ağacında kullanılabilir.

### Ortak döngü

`Gözlemle → Search ile plan aç veya Explore görevi seç → maliyet/sonuç önizle → onayla → aynı günlük simülasyonu çalıştır → sonuç ve nedenini göster`.

Build/Upgrade gün ilerletmez; ancak kit yatırımı yapar. Böylece oyuncu üs düzenlemesini güvenle yapabilir, Search ve Explore ise zaman ve stok kararı olur. Eksik kaynağa dayanan işlem başlatılmaz; HUD eksik kaynağı ve bir sonraki çözüm yolunu adlandırır.

## 7–12 yaş için anlaşılırlık

- Bir turda bir yeni kavram: önce güneş→güç, sonra sera→su/güç→gıda, sonra kalkan/radyasyon.
- Her kartta en fazla üç kısa sonuç: “Kurulumda 6 kit”, “Günde güç ve su kullanır”, “Güneş azsa daha az yiyecek üretir”.
- Barlar depo seviyesini; küçük oklar günlük tahmin edilen yönü gösterir. Renk yanında ikon, metin ve durum adı kullanılır.
- Sonuç cümlesi gözlem + neden + sonraki seçenek biçimindedir: “Bugün güneş azdı; panel daha az güç topladı; serayı yükseltebilir veya keşfi erteleyebilirsin.”
- Yanlış seçim utandırmaz. Kaynak azaldığında sebep gösterilir ve tek kullanımlık Mission Control acil paketi (oyun başına bir kez, kritik stokta veya sağlık 50'nin altındayken) açılır; kodda bu eşik uygulanır ve paket kargo olarak kaynaklara eklenir.
- Sayısal ayrıntı isteyen çocuk için açılır bilgi; varsayılan görünümde tam sayılar ve gündelik sözcükler.

## NASA veri katmanı

İlk gerçek NASA girdisi, Ay güney kutbunda konum/zamana göre aydınlanma ve gölge koşuludur. NASA PGDA Lunar Polar Illumination ürünleri LOLA tabanlı kutup aydınlanma ürünlerini sunar; NASA SVS 2023–2030 görselleştirmesinde iki saatlik adımlar kullanır. Ham ürün adaptörde görev zamanına göre güneşli süre faktörüne dönüştürülür; ham yüzde, gölge görüntüsü veya W/m² doğrudan simülasyona sokulmaz. Aydınlanma süresi panelin gerçek kWh üretimini tek başına vermez; oyun panel kapasitesi bir dengeleme parametresi olarak kalır. [NASA PGDA](https://pgda.gsfc.nasa.gov/products/69), [NASA SVS](https://svs.gsfc.nasa.gov/4930).

NASA POWER Dünya yüzeyi ışınımı ürünüdür; Ay çevre verisi gibi gösterilmez. [NASA POWER API](https://power.larc.nasa.gov/docs/tutorials/service-data-request/api/).

Her senaryo veri kartı sağlayıcı, dataset adı/kimliği, sürüm, zaman aralığı, koordinat, birim, kaynak bağlantısı, edinilme zamanı, NASA kredisi ve sadeleştirme notu taşır. İnternet yoksa aynı şemadaki paketli senaryo çalışır. Bu proje aşamasında canlı veri indirme yoktur; adaptör 0–1 `fraction` değerini doğrular. Radyasyon değeri şimdilik senaryo oyun puanıdır; NASA ölçümüymüş gibi sunulmaz.

## Doğrulama planı

Kod ve doküman aynı kabul kurallarını paylaşır:

- Başlangıçtaki kurulu modüller sahnedeki Habitat, SolarArray, WaterTank ile aynı.
- IceDrill aldığı güç oranında su üretir; güç yoksa su da yoktur.
- Ekip sağlığı 0 olunca `outcome` "lost", bütün hedefler tamamlanınca "won" döner.
- Kaynaklar 0–100, kit 0–30, sağlık 0–100 aralığında kalır; negatif stok oluşmaz.
- İki kişi her gün su, gıda ve oksijen tüketir; mevcut miktar ihtiyaca yetmiyorsa açık raporlanır.
- Güneş 0 ise solar enerji 0; güneş 0.5 ise L1 en çok 12; güneş 1 ise en çok 24 üretir.
- Güç azsa önce habitat, sonra isteğe bağlı makineler çalışır; isteğe bağlı makineler aynı oranda yavaşlar.
- Sera su, güç veya ışık olmadan ürün üretmez; ürün girdi kısıtlarına göre ölçeklenir.
- WaterTank geri kazandığı suyu ekip kullanımından alır; kaynak yaratmaz.
- Kalkan L1 radyasyon yükünü azaltır ama tek başına sıfırlamaz; yüksek seviye güç harcar.
- Rover bir gezi başına bir kere stok harcar ve Science verir; Search sample ve güç tüketir, her araştırma bir kez tamamlanır.
- `preview_build`/`preview_upgrade` mevcut durumdan bir günlük aynı simülasyonu çalıştırır; tahmin ile gerçek tur aynı algoritmayı kullanır.
- Güç ve ürün taşmaları raporlanır; oyuncu barın neden artmadığını anlayabilir.
- NASA paketi kaynak metadata'sız, yanlış schema'lı veya 0–1 dışı güneş faktörlü ise reddedilir ve yerel senaryoya dönülür.

## Oyuncu geri bildirimiyle doğrulama

Değer, “oyun eğlenceli miydi?” yanıtından tek başına çıkarılmaz. Küçük pilotta aynı ilişki için görev öncesi tahmin, oyun içi önizlemeyi fark etme, karar sonrası neden açıklaması ve yeni koşula transfer gözlenir. Örnek: oyuncu güneş azaldığında sera üretiminin ve panel gücünün ne olacağını yeni haritada yardım almadan tahmin edebiliyor mu? Ayrı olarak oyuncu görevi bulabiliyor mu ve arayüz metnini okuyabiliyor mu ölçülür; okuma güçlüğü bilim kavrayışıyla karıştırılmaz.

Her iterasyonda kayıt: `gözlem → hangi kural anlaşılmadı → UI mı model mi kaynaklı → değişiklik → aynı hedefi yeni görevde tekrar ölç`. Tek oyuncu yorumu denge değerini değiştirmek için tek başına yeterli değildir. Çocuk araştırmasında kimliksiz, asgari veri; gönüllü katılım ve veli/öğretmen gözetimi uygulanır. Varsayılan oyunda telemetry kapalıdır.

## Oyuncunun kendi başına öğrenmesi ve geri bildirim döngüsü

Öğretici, tüm kuralları bir ekranda anlatmaz. Oyuncuya bir ilişkiyi gösterir, seçimi ona bırakır, sonucu açıklar ve daha sonra farklı koşulda yeniden denemesini ister:

1. **İlk karşılaşma:** Bir görevde tek bir kavramı tanıt. Örneğin güneşli/koyu gün ile enerji arasındaki ilişki. Kısa metin ve görsel örnek kullan; sonraki kuralları henüz açma.
2. **Karar öncesi tahmin:** Build/Search/Explore önizlemesinden önce oyuncu bir resim/ok seçerek “artırır, azalır, aynı kalır” tahmini yapabilir. Bu isteğe bağlıdır ve cevabı kilitlemez.
3. **Sonuç ve sebep:** Gün sonunda gerçek değişimi göster, tahminle yan yana koy ve tek cümleyle nedenini belirt. Örn. “Güneş azdı; paneller daha az güç topladı; bu yüzden sera yavaşladı.”
4. **İpucuyla toparlanma:** İlk hata sonrası tek, bağlamsal ipucu; ikinci denemede daha açık yönlendirme; oyuncu isterse tam açıklama. Acil kargo oyunu kilitlemeden devam ettirir.
5. **Transfer görevi:** Sonraki görevde bir koşulu değiştir (daha az güneş, daha küçük su deposu, daha yüksek radyasyon). Oyuncu eski cevabı ezberlemek yerine aynı ilkeyi yeni durumda kullanabiliyor mu gözle.
6. **Kapanış özeti:** “Ne değişti / neden / başka koşulda ne yapardın?” üç kısa kart. Her terim için sözlük ve tekrar oynanabilir örnek bulunur.

### Öğrendiğimizi nasıl anlarız?

Geri bildirim, oyuncunun kendisi hakkında puan üretmek için değil, hangi oyun açıklamasının işe yaradığını bulmak için toplanır. Bir pilotta şu göstergeler ayrı raporlanır:

- **Kullanılabilirlik:** Oyuncu önizlemeyi buldu mu, maliyeti gördü mü, görevi yardım almadan başlatabildi mi?
- **Kavrayış:** Günlük stok ile üretim hızını ayırabiliyor mu? Bir seçimden sonra hangi girdi/çıktının neden değiştiğini açıklayabiliyor mu?
- **Transfer:** Farklı güneş veya stok koşulunda uygun karar verebiliyor mu?
- **Güven ve ilgi:** Sonuç oyuncunun beklediğiyle uyuştu mu; yeniden denemek veya başka strateji seçmek istiyor mu?
- **Erişilebilirlik:** Okuma zorluğu, ikon, renk veya dokunma hedefi bilim kavrayışından ayrı mı ölçüldü?

Test oturumunda görev öncesi görsel tahmin alınır; oyun sırasında sadece karar noktaları ve yardım kullanımı gözlemlenir; görev sonunda kısa sorular sorulur; sonra yeni koşullu görevle transfer ölçülür. Oyun telemetry'si varsayılan olarak kapalıdır. Araştırma için çocuk kimliği veya ses/görüntüsü gerekmez; gönüllü, asgari, kimliksiz kayıt ve uygun veli/öğretmen gözetimi kullanılır.

Her bulgu `gözlem → olası neden → model/UI/öğretici ayrımı → değişiklik → aynı hedefi yeni görevde tekrar ölçme` biçiminde izlenir. Tek bir oyuncunun yorumu katsayı değişikliği için yeterli sayılmaz. Örneğin çocuk sera suyunu gördüğü halde güç etkisini anlamıyorsa önce kart metni ve neden-sonuç geri bildirimi düzeltilir; model katsayısı yalnızca denge kanıtı varsa değiştirilir.

## Uygulama durumu

Bu revizyon simülasyon algoritmasını ve mimari sözleşmesini düzeltir. Mevcut HUD hâlâ sera için eski sabit delta ve “en düşük kaynak = sağlık” demosu kullanıyor; yeni çekirdeğe bağlı değildir. Tam oynanabilir entegrasyonda HUD sabit katsayıları kaldırılmalı, Build/Search/Explore önizlemeleri bu çekirdeği çağırmalı, günlük sonuçlar kaynak ve kalp barlarına buradan aktarılmalıdır. Bu UI bağlantısı yapılmadan eski HUD ile yeni simülasyonun birlikte çalıştığı iddia edilmemelidir.
