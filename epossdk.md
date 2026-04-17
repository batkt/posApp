Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

1

EPOS SDK  
ХЭРЭГЛЭГЧИЙН ГАРЫН АВЛАГА

Баримт бичгийг хариуцах нэгж: БХА
Баримт бичгийн нууцлалын зэрэглэл: Гадаад
Баримт бичгийн түвшин: 3
Баримт бичгийн хувилбар: 1.2

2025 ОН
Лавлагаа
SA-100-2024
Нууцыг хадгалах тухай
“EPOS SDK”
хэрэглэгчийн гарын авлага
Энэхүү баримтад тусгагдсан агуулга нь компанийн үйл ажиллагаатай холбоотой мэдээлэлд
үндэслэсэн болно. Баримтыг ашиглах этгээд нь компанитай байгуулсан гэрээ болон холбогдох
бусад журмын дагуу ашиглахыг зөвлөж байна. Гуравдагч этгээд ашиглахыг зөвшөөрснөөс бусад
тохиолдолд баримтыг дамжуулахыг хориглоно.
Энэ баримт нь байгууллагын өмч бөгөөд компанийн нууцад хамаарах, үл хамаарахаас
шалтгаалахгүй “Байгууллагын нууцын тухай хууль”-аар хамгаалагдана.
Баримтад гуравдагч этгээдийн буюу гаднын агуулга, материалыг зөвшөөрөлгүй хуулбарлан
ашиглаагүй болно.
Баримтын зориулалт  
Энэхүү гарын авлагад EPOS болон түүнтэй харилцах байгууллагуудтай өгөгдлийг аюулгүй
солилцоход шаардлагатай үйлдэл, ашиглах функцийн заавар, дамжуулах өгөгдлийн бүтэц мөн
ашиглагдах алгоритм зэргийг тайлбарласан.
2
Лавлагаа
SA-100-2024
Хяналтын хувилбар
Огноо
“EPOS SDK”
хэрэглэгчийн гарын авлага
Хувилбар
Баримт бичиг
бэлтгэсэн
2024-09-25
Хувилбар 1.0
Б.Чимэдцэеэ
Өөрчлөлийн агуулга
Шинэчилсэн
2025-01-21
Хувилбар 1.1
Б.Чимэдцэеэ

1. NoReceipt хүсэлтүүдийг хасав
2. Response талбаруудыг шинэчлэв
   3.Сүүлчийн гүйлгээ шалгах функц
   нэмсэн
3. Settlement – response field дээр
   нэмэлт field нэмсэн.
   2025-05-13
   Хувилбар 1.2
   Б.Чимэдцэеэ
4. AddRoute MSG  
   3
   Лавлагаа
   SA-100-2024
   Нэр томьёоны тайлбар:  
   №
   Нэр  
   “EPOS SDK”
   хэрэглэгчийн гарын авлага
   Тайлбар
   1
   EPOS төхөөрөмж НӨАТ баримтыг автоматаар бүртгэж банкны картаар хөнгөлөлт
   урамшууллын хөтөлбөрт хамрагдах боломжтой бэлэн бусаар төлбөр
   төлөх боломжтой карт уншигч төхөөрөмж юм.
   2
   Мерчант  
   Худалдаа үйлчилгээ эрхлэгч хувь хүн ба байгууллага.
   3
   Мерчантын
   баримтын хувь
   Мерчант нь төлбөр тооцоог хүлээн авсан болохыг баталгаажуулах
   баримт.
   4
   MCO
   M- Mandatory – Зайлшгүй байх талбар  
   C-Conditional – Ямар нэгэн нөхцөл болон шаардлагуудыг хангасан үед
   ирнэ  
   O-Optional – Сонголттой
   4

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

5

АГУУЛГА
Нууцыг хадгалах тухай ........................................................................................................................ 2
Хяналтын хувилбар .............................................................................................................................. 3
Нэр томьёоны тайлбар: ........................................................................................................................ 4

1. ТОХИРГОО ХИЙХ .................................................................................................................... 7
   1.1 Үндсэн ойлголт ........................................................................................................................... 7
   1.2 SDK Tool суулгах заавар ........................................................................................................... 8
   1.3 SDK connection constants............................................................................................................ 8
   1.4 SDK connection constants Main activity дээр хийгдэх жишээ код ........................................... 9
   1.5 SDK Message base response бүтэц, тайлбар ............................................................................ 10
   1.6 HealthCheck – Epos terminal config татах ................................................................................ 10
   1.6.1 Жишээ ................................................................................................................................. 10
2. Гүйлгээ ...................................................................................................................................... 12
   2.1 Sale ............................................................................................................................................. 12
   2.1.1 Sequence диаграмм ........................................................................................................... 12
   2.1.2 Жишээ ................................................................................................................................. 13
   2.2 Void ............................................................................................................................................ 15
   2.2.1 Sequence диаграмм ........................................................................................................... 15
   2.2.2 VoidCard .............................................................................................................................. 16
   2.2.3 Void...................................................................................................................................... 17
   2.3 Cashback .................................................................................................................................... 19
   2.3.1 Sequence диаграмм ........................................................................................................... 19
   2.3.2 Жишээ ................................................................................................................................. 20
   2.3 PreAuth....................................................................................................................................... 22
   2.4.2 Жишээ ................................................................................................................................. 22
   2.4 PreAuthCancel ........................................................................................................................... 24
   2.5.2 Жишээ ................................................................................................................................. 24
   2.5 PreAuthCompletion .................................................................................................................... 26
   2.6.1 Жишээ ................................................................................................................................. 26
   2.6 Settlement ................................................................................................................................... 27
   2.7.1 Sequence диаграмм ........................................................................................................... 27
   2.7.2 Жишээ ................................................................................................................................. 28
   2.7 CheckTrans ................................................................................................................................. 31
   2.7.1 Жишээ ................................................................................................................................. 31
   3 .TASK ТӨРЛИЙН МЕССЕЖ ......................................................................................................... 32
   3.1 CitizenCard ................................................................................................................................. 32

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

6

3.1.1 Sequence диаграмм ........................................................................................................... 32
3.1.2 Жишээ ................................................................................................................................ 33
3.2 PrintBitmap ................................................................................................................................ 35
3.2.1 Sequence диаграмм ........................................................................................................... 35
3.2.1 Жишээ ................................................................................................................................. 36
3.3 PrintBitmapFromFile.................................................................................................................. 37
3.3.1 Жишээ ................................................................................................................................. 37
3.4.1 Sequence диаграмм ........................................................................................................... 38
3.4.2 Жишээ ................................................................................................................................. 39
3.5 RePrintTotal ............................................................................................................................... 40
3.5.1 Sequence диаграмм ........................................................................................................... 40
3.5.2 Жишээ ................................................................................................................................. 41
3.6 ScanCode .................................................................................................................................... 42
3.6.1 Sequence диаграмм ........................................................................................................... 42
3.6.2 Жишээ ................................................................................................................................. 43
3.7 ReadRfCard ................................................................................................................................ 44
3.7.2 Жишээ ................................................................................................................................. 44
3.8 AddRoute ................................................................................................................................... 45
3.8.1 Жишээ ................................................................................................................................. 45 4. ХАВСРАЛТ................................................................................................................................. 47
4.1 Тасалбар(талон) хэвлэх ............................................................................................................ 47
4.1.1 Хэрэглэгчид очих баримтад хэвлэх талбарууд ................................................................ 47
4.1.2 Үлдэх хувь дээр хэвлэх талбарууд .................................................................................... 48
4.3 Алдааны кодын тайлбар .......................................................................................................... 50

Лавлагаа
SA-100-2024

1. ТОХИРГОО ХИЙХ
   1.1 Үндсэн ойлголт
   “EPOS SDK”
   хэрэглэгчийн гарын авлага
   EPOS SDK гэдэг нь андройд үйлдлийн системтэй пос төхөөрөмж дээр суусан харилцагч
   байгууллагын программ /аппликэйшн/ болон EPOS аппликэйшний хооронд борлуулалт, буцаалт,
   нэгтгэл болон бусад үйл ажиллагааны хүсэлтийг илгээж, гүйлгээний үр дүнг хүлээн авч дамжуулах
   зорилго бүхий дундын хэрэгсэл юм.
   Үүний тулд Датабэйнк ХХК-с гаргасан sdk /lib/ -ыг зааврын дагуу ашиглан хөгжүүлэлт хийх
   шаардлагатай болно.
   SDK нь харилцагчийн мэдээллийг нууцлалын өндөр түвшинд хадгалан гүйлгээг дамжуулах ба
   харилцагч байгууллагын систем болон карт суурьтай гүйлгээ хийх боломжийг олгож буй дундын
   хэрэгсэл юм.
   SDK дагуу хөгжүүлэлт хийж ажиллуулахад дараах шаардлага тавигдана.
   • Харилцагч байгууллага аппликэйшний хөгжүүлэлтийн орчинд SDK tool суулгасан байх.
   • Андройд пос төхөөрөмж нь интернэт сүлжээнд буюу зөвхөн Wi -Fi сүлжээгээр байнгын
   холболттой байх.
   • Epos дээрх Epos Open SDK болон хөгжүүлэлтэд ашиглаж байгаа Epos Open SDK
   хувилбарууд ижил байх.
   Зураг 1. SDK ерөнхий ойлголт
   Анхааруулга :  
   SDK функцүүдээс transaction төрлийн NoReceipt буюу баримт хэвлэхгүй функц ашиглан
   хөгжүүлэлт хийсэн бол EPOS SDK version 20 - с хойш баримт хэвлэгддэг болсныг анхаарна уу.
   7
   Лавлагаа
   SA-100-2024
   1.2 SDK Tool суулгах заавар  
   Flutter дээр суулгах заавар
   “EPOS SDK”
   хэрэглэгчийн гарын авлага
   Java дээр суулгах заавар
   ✓ Хэрэглэгч SDK tool суулгахдаа vscode
   дээрх android folder-г android studio
   программ дээр хуулж ажиллуулна.
   ✓ Хэрэглэгч android studio дээр Jar file
   оруулахын тулд android -> app -> libs
   хэсэгт хуулж суулгана. Хэрэв libs folder
   байхгүй бол шинээр libs folder үүсгэн
   хуулна.
   ✓ Хэрэглэгч Java программ дээр Jar file
   оруулахын тулд Poject folder – app – libs
   хэсэгт хуулж ажиллуулна.
   1.3 SDK connection constants
   Дараах тогтмол утгуудыг зарлаж Msg function буюу Epos open SDK функцуудыг ашиглахад заавал
   хэрэглэнэ.
   Key
   Value
   METHOD_CHANNEL
   Type
   app package name
   METHOD_HEALTH_CHECK
   String
   android.epos.payment.healthCheck
   METHOD_SALE
   String
   android.epos.payment.sale
   METHOD_VOID
   String
   android.epos.payment.void
   METHOD_VOID_CARD
   String
   android.epos.payment.voidCard
   METHOD_CASHBACK
   String
   android.epos.payment.cashback
   METHOD_PREAUTH
   String
   android.epos.payment.preAuth
   METHOD_PREAUTH_CANCEL
   String
   android.epos.payment.PreAuthCancel
   METHOD_PREAUTH_COMPLETION
   String
   android.epos.payment.preAuthCompletion String
   METHOD_CHECK_TRANS
   android.epos.payment.checkTrans
   METHOD_SETTLE
   String
   android.epos.payment.settle
   METHOD_CITIZEN_CARD
   String
   android.epos.payment.citizenCard
   METHOD_PRINT_TRANS
   String
   android.epos.payment.printTrans
   METHOD_PRINT_TRANS_TOTAL
   String
   android.epos.payment.printTransTotal
   METHOD_SCAN_CODE
   String
   android.epos.payment.scanCode
   METHOD_PRINT_BITMAP
   String
   android.epos.tasks.printBitmap
   METHOD_PRINT_BITMAP_FROM_FILE android.epos.tasks.printBitmapFile
   String
   METHOD_CHECK_PAPER
   String
   android.epos.tasks.checkPaper
   METHOD_READ_RF_CARD
   String
   android.epos.tasks.readRfCard
   METHOD_ADD_ROUTE
   String
   android.epos.tasks.addRoute
   String
   8

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

9

Жишээ код:

public class Constants {
// Method channel
public static final String METHOD_CHANNEL =
"mn.databank.epos_open_api_demo/epos_open_api_demo";

    // Methods
    public static final String METHOD_HEALTH_CHECK = "android.epos.payment.healthCheck";
    public static final String METHOD_SALE_NO_RECEIPT = "android.epos.payment.saleNoReceipt";
    public static final String METHOD_SETTLE = "android.epos.payment.settle";
    public static final String METHOD_SCAN_CODE = "android.epos.payment.scanCode";
    public static final String METHOD_PRINT_BITMAP = "android.epos.tasks.printBitmap";
    public static final String METHOD_ADD_ROUTE= "android.epos.tasks.addRoute";

}

1.4 SDK connection constants Main activity дээр хийгдэх жишээ код

package mn.databank.merchantdemo.ui; import
androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import mn.databank.eposopenapi.factory.EposTransAPIFactory; import
mn.databank.eposopenapi.factory.IEposTransAPI; import
mn.databank.eposopenapi.message.BaseResponse; import
mn.databank.eposopenapi.message.TransResponse;

public class MainActivity extends AppCompatActivity { public
IEposTransAPI eposTransAPI;

@Override

protected void onCreate(Bundle savedInstanceState) {
super.onCreate(savedInstanceState);
setContentView(R.layout.activity_main);
eposTransAPI = EposTransAPIFactory.createTransAPI();

}
@Override
protected void onActivityResult(int requestCode, int resultCode,
@Nullable Intent data) { super.onActivityResult(requestCode,
resultCode, data);

BaseResponse baseResponse = eposTransAPI.onResult(requestCode,
resultCode, data);

// when you didn't chose any one if (baseResponse == null) {
return;
}
boolean isTransResponse = baseResponse instanceof TransResponse; if
(isTransResponse) {
TransResponse response = (TransResponse) baseResponse;
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага
} else {
LogUtils.d("MainActivity", "response as" + baseResponse.getRspMsg());
}
}
}
}
}
1.5 SDK Message base response бүтэц, тайлбар
Хувьсагчийн нэр
Төрөл
Тайлбар
appId
string
Аппликейшн ID
rspCode
string
Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
Гүйлгээний хариу мессеж  
extraBundle
bundle
Request actual response
sdkVersion
string
Epos аппликейшнд байгаа SDK хувилбар
eposVersion
string
Epos аппликейшны хувилбар
prgName
string
Ашиглах гэж буй терминалын статик нэршил
commandType
string
Msg command Type
1.6 HealthCheck – Epos terminal config татах
Функцийн тайлбар
• Терминал асаж унтрах мөн гүйлгээ хийгдэх үед мэдээлэл татах шаардлагатай.
1.6.1 Жишээ  
Request:
HealthCheckMsg.Request request = new HealthCheckMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setCategory(SdkConstants.CATEGORY_HEALTH_CHECK);
Response:
result = await platform.invokeMethod(Constants.METHOD_HEALTH_CHECK);
if (result != null) {
BaseResponse res = BaseResponse.fromHealthRawJson(result);
10
Лавлагаа
SA-100-2024
Response талбарууд:
Хувьсагчийн нэр
“EPOS SDK”
хэрэглэгчийн гарын авлага
Төрөл
MCO
Тайлбар
merchantName
string
M КҮБ-ийн нэр
merchantId
string
M КҮБ-ийн дугаар
terminalId
string
M Терминал дугаар
commandType
string
M Msg command Type
sdkVersion
string
M Epos аппликейшнд байгаа SDK хувилбар
eposVersion
string
M Epos аппликейшны хувилбар
jsonRet  
mode
string
M Пос-ын ажиллаж буй орчин/Dev, Stage, Prod/
kub_name string
M КҮБ-ын нэр
reader_id
string
M Пос төхөөрөмжийн сериал дугаар
phone
string
O Терминал эзэмшигчийн утасны дугаар
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
11
Лавлагаа
SA-100-2024 2. Гүйлгээ
2.1 Sale
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• Мерчант аппликэйшнээс картын гүйлгээний хүсэлт илгээх.
2.1.1 Sequence диаграмм
Sequence диаграммын тайлбар
1-Sale request – Гүйлгээ хийх хүсэлт илгээх
2-Sale request – Гүйлгээ хийх хүсэлт дамжуулах
3-Payment display – Төлбөр төлөх цонх харуулах
4-Card read – Картаа уншуулах
5-Sale request – Гүйлгээний хүсэлт илгээх
6-Do transaction – Гүйлгээ хийх
7-Sale response – Гүйлгээний хүсэлтийн хариу илгээх
8-Show result – Гүйлгээний үр дүнг харуулах
8.1- Print receipt – Баримт хэвлэх
9-Sale response – Гүйлгээний хүсэлтийн хариуг дамжуулах
10-Sale response – Гүйлгээний хүсэлтийн хариуг дамжуулах
11-Show result – Гүйлгээний үр дүнг харуулах
12
Лавлагаа
SA-100-2024
2.1.2 Жишээ  
Request:
“EPOS SDK”
хэрэглэгчийн гарын авлага
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setAmount(5000);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_SALE);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.sale"
commandType
string
M 1
amount
string
M Гүйлгээний мөнгөн дүн. (Гүйлгээний үнийн дүн 0-ээс
дээш байна.) Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Төрө
л
MCO
Тайлбар
Response талбаруудын тайлбар:
Хувьсагчийн нэр
merchantName
strin
g
M Mерчант нэр. Баримтад заавал хэвлэх
merchantId
string
M Mерчант ID. Баримтад заавал хэвлэх
terminalId
string
M Банк терминал дугаар
traceNo
long
M Карт гаргагч банкны гүйлгээ шалгах дугаар
batchNo
long  
M Settlement дугаар
13

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

14

dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/ талаас
үүсгэгдсэн гүйлгээний хүсэлтийн дугаар (тухайн өдрийн
хувьд давтагдахгүй дугаар).  
transTime date M Гүйлгээ хийсэн огноо
amount string M Нийт 12 оронтой бутархайн орон 2 орон. Гүйлгээний мөнгөн
дүн. (Гүйлгээний үнийн дүн 0-ээс дээш байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2 орон.
Жишээлбэл: 2530.66
authCode string M Амжилттай гүйлгээний зөвшөөрлийн код
eposVersion string M Epos аппликейшнд байгаа SDK хувилбар
sdkVersion string M Epos аппликейшны хувилбар
cashbackAmount string M Картаас авч буй бэлэн мөнгөний дүн (зөвхөн cashback
гүйлгээнд ашиглагдана)
origAuthNo string M Гүйлгээний зөвшөөрлийн дугаар
origTraceNo string M Анхдагч гүйлгээний гүйлгээ гарсан дугаар
origRefNo string M Анхдагч гүйлгээний дугаар
origTransTime string M Анхдагч гүйлгээний огноо
origTradeNo string M Анхдагч гүйлгээний борлуулалтын дугаар
operation string M Гүйлгээний төрөл
prg_name string M Ашиглах гэж буй терминалын статик нэршил
oriTransactionType string M Анхдагч гүйлгээний төрөл
hasLoyalty string M Урамшуулалтай гүйлгээ эсэх
loyaltyID string M Урамшуулалын дугаар
noTxnAmount string M Урамшуулалгүй дүн
yesTxnAmount string M Урамшуулал бодсон дүн
usableLp string M Урамшууллын нэр
loyaltyProviderNam
e
string M Урамшуулал зарлагчийн нэр
rrn string M Карт хүлээн авагч банкны гүйлгээ лавлах дугаар
entryModeText string M Карт уншуулсан хэлбэр entry_mode_text = QR байвал
wallet_name ирнэ
cardHolderName string M Карт эзэмшигчийн нэр
rspCode string M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000 байна. Бусад
кодын лавлагааг /Хавсралт алдааны кодын тайлбар хэсгээс
харна уу./

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

15

Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
2.2 Void

2.2.1 Sequence диаграмм

Sequence диаграммын тайлбар

1- voidCard request – Амжилттай болсон гүйлгээг буцаалт хийх хүсэлт илгээх
1.1- voidCard request – Буцаалтын гүйлгээний хүсэлт илгээх
1.2- Card read– Картаа уншуулах  
1.3- voidCard request – Буцаалтын гүйлгээний хүсэлт илгээх
1.4-Do Void txn – Буцаалтын гүйлгээ хийх
1.5- voidCard response – Буцаалтын гүйлгээний хүсэлтийн хариу илгээх
1.6-Show result – Буцаалтын гүйлгээний үр дүнг харуулах
1.6.1-Print receipt – Буцаалтын гүйлгээний баримт хэвлэх
1.7- voidCard response – Буцаалтын гүйлгээний хүсэлтийн хариу илгээх
1.8- voidCard response – Буцаалтын гүйлгээний хүсэлтийн хариу илгээх
1.9-Show result – Буцаалтын гүйлгээний үр дүнг харуулах
2-void request (traceNo) – Амжилтгүй болсон гүйлгээг гүйлгээний дугаараар (traceNo) буцаах хүсэлт
илгээх
2.1- void request (traceNo) – Буцаалтын гүйлгээний хүсэлт илгээх
rspMsg string M Гүйлгээиий хариу мессеж
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага
2.2- void request (traceNo) – Буцаалтын гүйлгээний хүсэлт илгээх
2.3-Do void txn – Буцаалтын гүйлгээ хийх
2.4-void response– Гүйлгээний хүсэлтийн хариу илгээх
2.5-Show result – Гүйлгээний үр дүнг харуулах
2.5.1-Print receipt – Буцаалтын гүйлгээний баримт хэвлэх
2.6- void response – Буцаалтын гүйлгээний хүсэлтийн хариу илгээх
2.7- void response – Буцаалтын гүйлгээний хүсэлтийн хариу илгээх
2.8-Show result – Буцаалтын гүйлгээний үр дүнг харуулах
2.2.2 VoidCard
Функцийн тайлбар
Амжилттай болсон гүйлгээг хэрэглэгчийн гүйлгээ хийсэн карт уншуулан буцаалт хийх бөгөөд
баримт хэвлэхгүй.
2.2.3.1 Жишээ  
Request:
SaleNoReceiptMsg.Request request = new
SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_VOID_CARD);
Response :
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M
"android.epos.payment.voidCard"
commandType
string
M
5
dbRefNo
string
M
Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
16

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

17

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
merchantName string M КҮБ-ийн нэр
merchantId string M КҮБ-ийн дугаар
terminalId string M Терминал дугаар
cardNo string M Карт дугаар
cardType string M Карт төрөл
traceNo string M Гүйлгээний дугаар
batchNo string M Settlement дугаар
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
transTime string M Гүйлгээ хийсэн огноо
amount string M Мөнгөн дүн
authCode string M Амжилттай гүйлгээний зөвшөөрлийн код
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

2.2.3 Void

Функцийн тайлбар
• Амжилтгүй болсон гүйлгээг гүйлгээний дугаараар (traceNo) дамжуулан буцаалт хийх
бөгөөд баримт хэвлэхгүй.

2.2.3.1 Жишээ

Request:
SaleNoReceiptMsg.Request request = new
SaleNoReceiptMsg.Request();  
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_VOID);

Response :

BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

18

Request талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.void"
commandType string M 3
traceNo string M Гүйлгээний дугаар
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
merchantName string M КҮБ-ийн нэр
merchantId string M КҮБ-ийн дугаар
terminalId string M Терминал дугаар
cardNo string M Карт дугаар
cardType string M Карт төрөл
traceNo string M Гүйлгээний дугаар
batchNo string M Settlement дугаар
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
transTime string M Гүйлгээ хийсэн огноо
amount string M Мөнгөн дүн
authCode string M Амжилттай гүйлгээний зөвшөөрлийн код
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional  
Лавлагаа
SA-100-2024
2.3 Cashback
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• Хэрэглэгч төлбөрийн гүйлгээн дээр нэмэлтээр КҮБ-ээс бэлэн мөнгө авах үед хэрэглэгдэх
API. Гүйлгээний мөнгөн дүн болон бэлэн мөнгө, шимтгэл нэмсэн дүнгээр нийт дүнг бодно.
2.3.1 Sequence диаграмм
Sequence диаграммын тайлбар
1-Cashback request – Гүйлгээ хийх хүсэлт илгээх
2-Cashback request – Гүйлгээ хийх хүсэлт дамжуулах
3-Payment display – Төлбөр төлөх цонх харуулах
4-Card read – Картаа уншуулах
5-Cashback request – Гүйлгээний хүсэлт илгээх
6-Do cashback transaction – Гүйлгээ хийх
7-Cashback response – Гүйлгээний хүсэлтийн хариу илгээх
8-Show result – Гүйлгээний үр дүнг харуулах
8.1-Print receipt – Баримт хэвлэх
9-Sale response – Гүйлгээний хүсэлтийн хариуг дамжуулах
10-Sale response – Гүйлгээний хүсэлтийн хариуг дамжуулах
11-Show result – Гүйлгээний үр дүнг харуулах
12- Give money - КҮБ-ээс бэлэн мөнгө авах
19

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

20

2.3.2 Жишээ

Request:

SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();  
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setAmount(5000);
request.setCashbackAmount(6000);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_CASHBACK);

Response:

BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getFee()
response.getRspCode()
response.getRspMsg();

Request талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.cashback"
commandType string M 8
amount string M Гүйлгээний мөнгөн дүн. (Гүйлгээний үнийн дүн 0-ээс
дээш байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
cashbackAmount string M Бэлэн авах мөнгөн дүн
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
merchantName string M КҮБ-ийн нэр
merchantId string M КҮБ-ийн дугаар
terminalId string M Терминал дугаар
cardNo string M Карт дугаар
cardType string M Карт төрөл
Лавлагаа
SA-100-2024
traceNo
“EPOS SDK”
хэрэглэгчийн гарын авлага
string
M Гүйлгээний дугаар
batchNo
string
M Settlement дугаар
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
transTime
date
M Гүйлгээ хийсэн огноо
amount
string
M Худалдан авалтын үнийн дүн
cashbackAmount
string
M Бэлэн авсан мөнгөн дүн
fee
string
M Бэлэн мөнгө авсны шимтгэл
authCode
string
M Амжилттай гүйлгээний зөвшөөрлийн код
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditiol
21
Лавлагаа
SA-100-2024
2.3 PreAuth
Функцийн тайлбар
“EPOS SDK”
хөгжүүлэлтийн гарын авлага  
• Үйлчлүүлэгч авах үйлчилгээний төлбөрөө урьдчилан төлж (100% болон тодорхой хувиар)
захиалгаа баталгаажуулж буй төлбөрийн хэлбэр юм. Ингэснээр урьдчилж төлсөн төлбөр
түгжигдэх ба өөр худалдан авалт хийхэд урьдчилгаа гүйлгээний дүнг хассан дүнгээр
үлдэгдэл шалгана.  
2.4.2 Жишээ  
Request:
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setAmount(5000);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_PRE_AUTH);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.preAuth"
commandType
string
M 12
amount
string
M Гүйлгээний мөнгөн дүн. Нийт 12 оронтой
бутархайн орон 2 орон. (Гүйлгээний үнийн дүн 0
ээс дээш байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
22

Лавлагаа
SA-100-2024
“EPOS SDK”
хөгжүүлэлтийн гарын авлага

23

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл

MCO Нөхцөл Тайлбар  
merchantName string M status_code = true КҮБ-ийн нэр
merchantId string M status_code = true КҮБ-ийн дугаар
terminalId string M status_code = true Терминал дугаар
cardNo string M status_code = true Картын дугаар
cardType string M status_code = true Картын төрөл
traceNo string M status_code = true Карт гаргагч банкны гүйлгээ шалгах дугаар
batchNo string M status_code = true Settlement дугаар
dbRefNo
string
M status_code = true Харилцагч байгууллагын программ
/аппликэйшн/ талаас үүсгэгдсэн гүйлгээний
хүсэлтийн дугаар (тухайн өдрийн хувьд
давтагдахгүй дугаар).  
transTime string M status_code = true Гүйлгээ хийсэн огноо
amount
string
M status_code = true Гүйлгээний мөнгөн дүн. (Гүйлгээний үнийн дүн
0-ээс дээш байна.)
Нийт 12 оронтой бутархайн орон 2 орон.
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
authCode string M status_code = true Амжилттай гүйлгээний зөвшөөрлийн код  
rspCode string
M status_code = true Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт
алдааны кодын тайлбар хэсгээс харна уу./
rspMsg string M status_code = true Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Лавлагаа
SA-100-2024
2.4 PreAuthCancel
Функцийн тайлбар
“EPOS SDK”
хөгжүүлэлтийн гарын авлага  
• Үйлчлүүлэгч урьдчилгаа барьцаа болон баталгаажуулсан барьцаа гүйлгээг буцаалт хийх
бөгөөд барьцаа гүйлгээг баталгаажуулсан бол буцаалт хийх боломтжгүй байна.  
2.5.2 Жишээ  
Request:
SaleNoReceiptMsg.Request request = new
SaleNoReceiptMsg.Request(); Bundle args = new Bundle();
request.setExtraBundle(args);
request.setRrn('0001');
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_PRE_AUTH_CANCEL);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.preAuthCancel"
commandType
string
M 13
amount
string
M Гүйлгээний мөнгөн дүн. Нийт 12 оронтой
бутархайн орон 2 орон. (Гүйлгээний үнийн дүн 0
ээс дээш байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
rrn
string
M Карт хүлээн авагч банкны гүйлгээ лавлах дугаар
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
24

Лавлагаа
SA-100-2024
“EPOS SDK”
хөгжүүлэлтийн гарын авлага

25

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл

MCO Нөхцөл Тайлбар  
merchantName string M status_code = true КҮБ-ийн нэр
merchantId string M status_code = true КҮБ-ийн дугаар
terminalId string M status_code = true Терминал дугаар
cardNo string M status_code = true Картын дугаар
cardType string M status_code = true Картын төрөл
traceNo string M status_code = true Карт гаргагч банкны гүйлгээ шалгах дугаар
batchNo string M status_code = true Settlement дугаар
dbRefNo
string
M status_code = true Харилцагч байгууллагын программ
/аппликэйшн/ талаас үүсгэгдсэн гүйлгээний
хүсэлтийн дугаар (тухайн өдрийн хувьд
давтагдахгүй дугаар).  
transTime string M status_code = true Гүйлгээ хийсэн огноо
amount
string
M status_code = true Гүйлгээний мөнгөн дүн. (Гүйлгээний үнийн дүн
0-ээс дээш байна.)
Нийт 12 оронтой бутархайн орон 2 орон.
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
authCode string M status_code = true Амжилттай гүйлгээний зөвшөөрлийн код  
rspCode string
M status_code = true Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт
алдааны кодын тайлбар хэсгээс харна уу./
rspMsg string M status_code = true Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Лавлагаа
SA-100-2024
2.5 PreAuthCompletion
Функцийн тайлбар
“EPOS SDK”
хөгжүүлэлтийн гарын авлага  
• Үйлчлүүлэгч урьдчилгаа барьцаат гүйлгээг баталгаажуулах үед ашиглагдана.  
2.6.1 Жишээ  
Request:
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setAmount(5000);
request.setDbRefNo(‘20220404151043’);
request.setRefNo(‘0001’);
request.setCategory(SdkConstants.CATEGORY_PRE_AUTH_COMPLETION);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.preAuthCompletion"
commandType
string
M 13
amount
string
M Баталгаажуулсан мөнгөн дүн. Нийт 12 оронтой
бутархайн орон 2 орон. (Гүйлгээний үнийн дүн 0
ээс дээш байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
rrn
string
M Карт хүлээн авагч банкны гүйлгээ лавлах дугаар
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
26
Лавлагаа
SA-100-2024
2.6 Settlement
Функцийн тайлбар
“EPOS SDK”
хөгжүүлэлтийн гарын авлага  
• Тухайн КҮБ-н пос төхөөрөмж дээр хийгдсэн нийт гүйлгээний нэгтгэл дүн харуулах.
Сүүлчийн гүйлгээ хийгдсэн хугацаанаас дараагийн сеттлемент хийгдсэн хугацаанаас
дараагийн сеттлемент хийгдэх хүртэл хийгдсэн гүйлгээний нэгтгэл дүнг авах зорилготой.  
2.7.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - Settlement request – Гүйлгээний нэгтгэл дүнг авах хүсэлт илгээх
2 - Settlement request - Гүйлгээний нэгтгэл дүнг авах хүсэлтийг дамжуулах
3 - Settlement request - Гүйлгээний нэгтгэл дүнг авах хүсэлтийг дамжуулах
4 - SaveSettlementTrans – Нэгтгэл дүнг тооцоолох
5 - Settlement response - Гүйлгээний нэгтгэл дүнг авах хүсэлтийн хариу буцаах
6 - Show result – Үр дүнг харуулах
6.1 – Print receipt – Баримт хэвлэх
7 - Settlement response - Гүйлгээний нэгтгэл дүнг авах хүсэлтийн хариуг дамжуулах
8 - Settlement response - Гүйлгээний нэгтгэл дүнг авах хүсэлтийн хариуг дамжуулах
9 - Show result – Үр дүнг харуулах
27

Лавлагаа
SA-100-2024
“EPOS SDK”
хөгжүүлэлтийн гарын авлага

28

2.7.2 Жишээ

Request:
SaleNoReceiptMsg.Request request = new
SaleNoReceiptMsg.Request(); Bundle args = new Bundle();
request.setExtraBundle(args);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_SETTLE);

Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();

Request талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.settle"
commandType string M 10
terminalId string M Терминал дугаар
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Нөхцөл Тайлбар  
operation string
M status_code =
true Төрөл:
“SALE” – Гүйлгээ
“VOID” – Буцаалт
“SETTLEMENT” – Нэгтгэл
dbRefNo string
M status_code =
true
Харилцагч байгууллагын программ
/аппликэйшн/ талаас үүсгэгдсэн гүйлгээний
хүсэлтийн дугаар (тухайн өдрийн хувьд
давтагдахгүй дугаар). (тухайн өдрийн хувьд
давтагдахгүй дугаар).
rspCode string
M status_code =
true
Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт
алдааны кодын тайлбар хэсгээс харна уу./

Лавлагаа
SA-100-2024
“EPOS SDK”
хөгжүүлэлтийн гарын авлага

29

rspMsg string M status_code =
true
Гүйлгээний хариу мессеж  
saleCount string M status_code =
true Гүйлгээний нийт тоо
saleTotal string
M status_code =
true
Гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон.
Жишээлбэл: 2530.66

voidCount string M status_code =
true Буцаалт хийсэн гүйлгээний тоо
voidTotal string
M status_code =
true
Буцаагдсан гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон.  
Жишээлбэл: 2530.

date string M status_code =
true Гүйлгээ хийдсэн сар өдөр “MM/DD”
time string M status_code =
true Гүйлгээ хийдсэн цаг минут “hh:mm:ss”
startDate string
M status_code =
true
Эхэлсэн хугацаа  
“YYYYMMDDhhmmss”
endDate string
M status_code =
true
Дууссан хугацаа
“YYYYMMDDhhmmss”
terminalDate string
M status_code =
true
ПОС-оор үүсгэсэн гүйлгээ эхлүүлсэн огноо.
(YYYYMMDDhhmmss)  
batchNo string M status_code =
true Settlement дугаар
terminalId string M status_code =
true Банкны терминал дугаар
merchantId string M status_code =
true Мерчант ID
PassSaleCount string M status_code =
true Pass аппликэйшны гүйлгээний нийт тоо

Лавлагаа
SA-100-2024
“EPOS SDK”
хөгжүүлэлтийн гарын авлага

30

PassSaleTotal
string
M status_code =
true
Pass аппликэйшны гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон.Жишээлбэл: 2530.66  
PassVoidCount string M status_code =
true
Pass аппликэйшны буцаалтын гүйлгээний нийт
тоо
PassVoidTotal
string
M status_code =
true
Pass аппликэйшны буцаагдсан гүйлгээний нийт
дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон. Жишээлбэл: 2530.66  
DigiPaySaleCount string M status_code =
true DigiPay аппликэйшны гүйлгээний нийт тоо
DigiPaySaleTotal
string
M status_code =
true
DigiPay аппликэйшны гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон. Жишээлбэл: 2530.66
DigiPayVoidCount string M status_code =
true
DigiPay аппликэйшны буцаалтын гүйлгээний
нийт тоо
DigiPayVoidTotal
string
M status_code =
true
DigiPay аппликэйшны буцаагдсан гүйлгээний
нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон. Жишээлбэл: 2530.66  
KBLPCount string M status_code =
true Урамшуулалтай гүйлгээний тоо
KBLPTotal
string
M status_code =
true
Урамшуулалтай гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон.Жишээлбэл: 2530.66  
CollinsonCount string M status_code =
true Collinson урамшуулалтай гүйлгээний тоо
CollinsonTotal
string
M status_code =
true
Collinson урамшуулалтай гүйлгээний нийт дүн
(Гүйлгээний үнийн дүн 0-с дээш байна. Бутархай
тоог зөвшөөрнө. Бутархай тооны нарийвчлал 2
орон.Жишээлбэл: 2530.66
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Лавлагаа
SA-100-2024
2.7 CheckTrans
Функцийн тайлбар
“EPOS SDK”
хөгжүүлэлтийн гарын авлага  
• Гүйлгээ амжилттай болсон эсэхийг шалгах үед ашиглана.
Анхааруулга: Нэгтгэл дүн (Settlement) хэвлэгдсэн тохиолдолд тухайн нэгтгэлд багтснаас хойшхи
гүйлгээг харах боломжтой.
2.7.1 Жишээ  
Request:
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_CHECK_TRANS);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TransResponse response = (TransResponse) baseResponse;  
response.getMerchantName()
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.checkTrans"
commandType
string
M 44
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Response талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
rspCode
string
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт
алдааны кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
31
Лавлагаа
SA-100-2024
3 .TASK ТӨРЛИЙН МЕССЕЖ
“EPOS SDK”
хэрэглэгчийн гарын авлага
TRANSACTION төрлийн мессежний хариу ( response ) талбарууд
Хувьсагчийн нэр
Төрөл
Тайлбар
qrCode
string
Уншуулсан QR код
dbRefNo
string
Мессежний дахин давдагдашгүй дугаар
cameraType
int
Камерны төрөл ()
jsonRet
string
Additional data
3.1 CitizenCard
Функцийн тайлбар
• Иргэний үнэмлэхийн мэдээлэл авах хүсэлт илгээх үед дуудах бөгөөд баримт хэвлэхгүй.
3.1.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - CitizenCard request – Иргэний үнэмлэхийн мэдээлэл авах хүсэлт илгээх
2 - CitizenCard request - Иргэний үнэмлэхийн мэдээлэл авах хүсэлтийг дамжуулах
3 - CitizenCard request - Иргэний үнэмлэх уншуулах
4 - Show result – Иргэний үнэмлэхийн мэдээлэл харуулах
5 - CitizenCard response - Иргэний үнэмлэхийн мэдээлэл авах хүсэлтийн хариуг дамжуулах
6 - CitizenCard response - Иргэний үнэмлэхийн мэдээлэл авах хүсэлтийн хариу буцаах
7 - Show result – Иргэний үнэмлэхийн мэдээлэл харуулах
32
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

33

3.1.2 Жишээ

Request:

SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();  
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_CITIZEN_CARD);
Response:

BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;  
response.getMerchantName();
response.jsonResp();
response.getRspCode();
response.getRspMsg();

Request талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.citizenCard",
commandType string M 24
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
merchantName string M КҮБ-ийн нэр
merchantId string M КҮБ-ийн дугаар
terminalId string M Терминал дугаар
jsonResp string M  
 aimag_sum date M Үнэмлэх олгосон огноо
bairlal_code string M  
 duusah_ognoo date M Хүчинтэй огноо
hayag string M Хаягийн мэдээлэл
huis string M Хүйс
id date M  
Лавлагаа
SA-100-2024
ner
“EPOS SDK”
хэрэглэгчийн гарын авлага
string
M Нэр
olgoson_gazar
string
M Улсын Бүртгэлийн Ерөнхий Газар
ovog
string
M Овог
register_no
string
M Регистр дугаар
torson_ognoo
string
M Төрсөн огноо
urgiin_ovog
string
M Ургийн овог
rspCode
string
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
34
Лавлагаа
SA-100-2024
3.2 PrintBitmap
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• Гүйлгээний баримтыг өөрийн загвараар баримт хэвлэх хүсэлтийг амжилттай картын
гүйлгээний хүсэлт болгоны араас заавал дуудна.
3.2.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - printBitmap request – Гүйлгээний баримтыг өөрийн загвараар хэвлэх хүсэлт илгээх
2 - printBitmap request - Гүйлгээний баримтыг өөрийн загвараар хэвлэх хүсэлт илгээх
3 - printBitmap() - Гүйлгээний баримт хэвлэх
4 - Show result – Гүйлгээний баримт харуулах
5 - printBitmap response - Гүйлгээний баримтыг өөрийн загвараар хэвлэх хүсэлтийн хариу буцаах
6 - printBitmap response - Гүйлгээний баримтыг өөрийн загвараар хэвлэх хүсэлтийн хариу буцаах
7 - Show result – Үр дүн харуулах
35
Лавлагаа
SA-100-2024
3.2.1 Жишээ
Request:
“EPOS SDK”
хэрэглэгчийн гарын авлага
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setBitmap(BITMAP BASE64 STRING);
request.setCategory(SdkConstants.CATEGORY_PRINT_BITMAP);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;
response.jsonRet();
response.getRspCode()
;response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.printBitmap",
commandType
string
M 28
amount
string
M Нийт 12 оронтой бутархайн орон 2 орон. Гүйлгээний
мөнгөн дүн. (Гүйлгээний үнийн дүн 0-ээс дээш
байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Response талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
rspCode
string
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
36
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

37

3.3 PrintBitmapFromFile

Функцийн тайлбар
• Гүйлгээний баримтыг өөрийн загвараар баримт хэвлэх хүсэлтийг амжилттай картын
гүйлгээний хүсэлт болгоны араас заавал дуудна. Их хэмжээний зурган файл дамжуулах
зорилготой.
3.3.1 Жишээ

Request:
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();  
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setBitmap(BITMAP BASE64 STRING);
request.setCategory(SdkConstants.CATEGORY_PRINT_BITMAP_FROM_FILE);

Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;
response.jsonRet();
response.getRspCode()
;response.getRspMsg();

Request талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.printBitmap",
commandType string M 28
amount string M Нийт 12 оронтой бутархайн орон 2 орон. Гүйлгээний
мөнгөн дүн. (Гүйлгээний үнийн дүн 0-ээс дээш
байна.)
Бутархай тоог зөвшөөрнө. Бутархай тооны
нарийвчлал 2 орон. Жишээлбэл: 2530.66
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
imgPath string M Зурагны зам
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
rspCode string M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg string M Гүйлгээний хариу мессеж  
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
3.4 RePrint Trans
Функцийн тайлбар
• Гүйлгээг дахин хэвлэх хүсэлт илгээх үед дуудах бөгөөд баримт хэвлэхгүй.
3.4.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - reprintTrans request – Гүйлгээг дахин хэвлэх хүсэлт илгээх
2 - reprintTrans request - Гүйлгээг дахин хэвлэх хүсэлт илгээх
3 - reprintTrans () - Гүйлгээг дахин хэвлэх хүсэлт илгээх
4 - Show result – Дахин хэвлэсэн гүйлгээний үр дүнг харуулах
5 - reprintTrans response - Гүйлгээг дахин хэвлэх хүсэлтийн хариу буцаах
6 - reprintTrans response - Гүйлгээг дахин хэвлэх хүсэлтийн хариу буцаах
7 - Show result – Үр дүн харуулах
38
Лавлагаа
SA-100-2024
3.4.2 Жишээ  
Request:
“EPOS SDK”
хэрэглэгчийн гарын авлага
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setTraceNo(0001);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_PRINT_TRANS);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;
response.jsonRet();
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.reprintTrans",
commandType
string
M 19
traceNo
string
M Карт гаргагч банкны гүйлгээ шалгах дугаар
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Response талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
rspCode
string
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
39
Лавлагаа
SA-100-2024
3.5 RePrintTotal
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх хүсэлт илгээх үед дуудах бөгөөд баримт
хэвлэхгүй.
3.5.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - reprintTotal request – Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх хүсэлт илгээх
2 - reprintTotal request - Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх хүсэлт илгээх
3 - reprintTotal () – Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх
4 - Show result – Дахин хэвлэсэн гүйлгээний үр дүнг харуулах
5 - reprintTotal response - Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх хүсэлтийн хариу илгээх
6 - reprintTotal response - Нийт гүйлгээний мэдээллийг баримт дээр хэвлэх хүсэлтийн хариу илгээх
7 - Show result – Үр дүн харуулах
40
Лавлагаа
SA-100-2024
3.5.2 Жишээ  
Request:
“EPOS SDK”
хэрэглэгчийн гарын авлага
SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);  
request.setReprintType(1);
request.setDbRefNo(‘20220404151043’);
request.setCategory(SdkConstants.CATEGORY_PRINT_TRANS_TOTAL);
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;
response.jsonRet();  
response.getRspCode()
response.getRspMsg();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.reprintTotal",
commandType
string
M 20
reprintTypeNo
string
M Гүйлгээний дугаар
dbRefNo
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Response талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
rspCode
string
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
41
Лавлагаа
SA-100-2024
3.6 ScanCode
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• QR болон Barcode унших хүсэлт илгээх үед дуудах бөгөөд баримт хэвлэхгүй.
3.6.1 Sequence диаграмм
Sequence диаграммын тайлбар
1 - scanCode request – QR болон Barcode унших хүсэлт илгээх
2 - scanCode request - QR болон Barcode унших хүсэлтийг дамжуулах
3 - scanCode() - QR болон Barcode унших  
4 - Show result – Үр дүнг харуулах
5 - scanCode response - QR болон Barcode унших хүсэлтийн хариу дамжуулах
6 - scanCode response - QR болон Barcode унших хүсэлтийн хариу дамжуулах
7 - Show result – Үр дүнг харуулах
42
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

43

3.6.2 Жишээ

Request:

SaleNoReceiptMsg.Request request = new SaleNoReceiptMsg.Request();  
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setCameraType(SdkConstants.REAR);
request.setCategory(SdkConstants.CATEGORY_SCAN_CODE);

Response:

BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);  
TaskResponse response = (TaskResponse) baseResponse;
response.jsonRet();
response.getRspCode()
;response.getRspMsg();

Request талбаруудын тайлбар:
Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.scanCode",
commandType string M 35
cameraType string M  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Response талбаруудын тайлбар:

Хувьсагчийн нэр Төрөл MCO Тайлбар
category string M "android.epos.payment.scanCode",
commandType string M 35
qrCode string M QR код
cameraType string M  
dbRefNo string M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
rspCode string M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg string M Гүйлгээний хариу мессеж  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional

Лавлагаа
SA-100-2024
3.7 ReadRfCard
Функцийн тайлбар
“EPOS SDK”
хэрэглэгчийн гарын авлага
• NFC буюу RF карт унших хүсэлт илгээх үед дуудах бөгөөд баримт хэвлэхгүй.
3.7.2 Жишээ  
Request:
RFCardMsg.Request request = new RFCardMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setCategory(SdkConstants.CATEGORY_READ_RF_CARD);
try {
this.eposTransAPI.startTrans(this, request);
} catch (Exception e) {
e.printStackTrace();
}
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);
TaskResponse response = (TaskResponse) baseResponse;
response.getRspCode()
;response.getRspMsg();
response.jsonRet();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.readRfCard",
commandType
string
M 42
cameraType
string
M  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
Response талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment. readRfCard",
commandType
string
M 42
qrCode
string
M QR код
cameraType
string
M  
dbRefNo
string
rspCode
string
M Харилцагч байгууллагын программ /аппликэйшн/
талаас үүсгэгдсэн гүйлгээний хүсэлтийн дугаар
(тухайн өдрийн хувьд давтагдахгүй дугаар).  
M Гүйлгээний хариу код
44
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага
Гүйлгээ амжилттай хийгдсэн бол rspCode = 000
байна. Бусад кодын лавлагааг /Хавсралт алдааны
кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
json ret  
string
rf_card_id
rf_card_status
M NFC Картын дугаар
string
M NFC Картын төлөв
rf_card_protocol
string
M NFC Картын протокол
rf_card_id_info
string
M NFC Картын мэдээлэл
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
3.8 AddRoute
Функцийн тайлбар
• Route буюу хандалт хийх хаягийн ПОС төхөөрөмжид нэмэх
3.8.1 Жишээ  
Request:
AddRouteMsg.Request request = new AddRouteMsg.Request();
Bundle args = new Bundle();
request.setExtraBundle(args);
request.setIp(“”);
request.setPort(“”);
request.setCategory(SdkConstants.CATEGORY_ADD_ROUTE);
try {
this.eposTransAPI.startTrans(this, request);
} catch (Exception e) {
e.printStackTrace();
}
Response:
BaseResponse baseResponse = eposTransAPI.onResult(requestCode, resultCode, data);  
TaskResponse response = (TaskResponse) baseResponse;
response.getRspCode();
response.getRspMsg();
response.jsonRet();
Request талбаруудын тайлбар:
Хувьсагчийн нэр
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.readRfCard",
commandType
string
M 45
cameraType
string
M  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
45
Лавлагаа
SA-100-2024
Response талбаруудын тайлбар:
Хувьсагчийн нэр
“EPOS SDK”
хэрэглэгчийн гарын авлага
Төрөл
MCO
Тайлбар
category
string
M "android.epos.payment.addRoute",
commandType
string
M 45
qrCode
string
M QR код
cameraType
string
M  
dbRefNo
string
rspCode
string
M Харилцагч байгууллагын программ
/аппликэйшн/ талаас үүсгэгдсэн гүйлгээний
хүсэлтийн дугаар (тухайн өдрийн хувьд
давтагдахгүй дугаар).  
M Гүйлгээний хариу код
Гүйлгээ амжилттай хийгдсэн бол rspCode =
000 байна. Бусад кодын лавлагааг /Хавсралт
алдааны кодын тайлбар хэсгээс харна уу./
rspMsg
string
M Гүйлгээний хариу мессеж  
json ret  
Тайлбар: MCO M - Mandatory, O – Optional, C- Conditional
46
Лавлагаа
SA-100-2024 4. ХАВСРАЛТ
4.1 Тасалбар(талон) хэвлэх
“EPOS SDK”
хэрэглэгчийн гарын авлага
Амжилттай гүйлгээ бүрийн хариунд (response) ирсэн өгөгдлөөс доорх талбаруудыг тасалбар дээр
хэвлэж болно.
4.1.1 Хэрэглэгчид очих баримтад хэвлэх талбарууд
Талбар
Хэвлэх нэр
Хэвлэх эсэх
amount
Төлсөн дүн
rrn  
RRN  
Заавал
Тайлбар
Гүйлгээний мөнгөн дүн.
(Гүйлгээний үнийн дүн 0-с дээш
байна. Бутархай тоог зөвшөөрнө.
Бутархай тооны нарийвчлал 2 орон.
Жишээлбэл: 2530.66)
Заавал  
entryModeText
Хэлбэр  
Заавал  
Карт хүлээн авагч банкны гүйлгээ
лавлах дугаар
terminal_id  
Карт уншуулсан хэлбэр  
Terminal ID  
Заавал  
merchantId  
Банк терминал дугаар  
Merchant ID  
Заавал  
merchantName  
Мерчант ID. Баримтад заавал хэвлэх
Дэлгүүрийн нэр  
authCode
Хэвлэж болно Мерчант нэр. Баримтад заавал хэвлэх
Амжилттай
гүйлгээний
Амжилттай
гүйлгээний
зөвшөөрлийн код
Заавал
Амжилттай гүйлгээний зөвшөөрлийн
код
47
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

48

4.1.2 Үлдэх хувь дээр хэвлэх талбарууд

МЕРЧАНТ-д үлдэх хувь дээр карт эзэмшигчээр гарын үсэг зурах мөн Merchant Copy гэсэн үг
оруулах. Дахин хэвлэж байгаа үед Дахин хэвлэсэн гэсэн үг оруулах. Урамшуулалтай холбоотой
утгууд ирсэн бол заавал хэвлэх шаардлагатай.
Санамж: Sale хүсэлтийн response хэсэгт ирсэн талбараас харна уу.

Талбар Хэвлэх нэр Хэвлэх эсэх Тайлбар

amount  
Дүн Заавал  
Гүйлгээний мөнгөн дүн.
(Гүйлгээний үнийн дүн 0-с дээш байна.
Бутархай тоог зөвшөөрнө. Бутархай
тооны нарийвчлал 2 орон. Жишээлбэл:
2530.66)
traceNo Trace No  
Заавал  
Карт гаргагч банкны гүйлгээ шалгах
дугаар
dbRefNo DbRef s
Заавал  
ХСН талын хүсэлтийн дугаар (тухайн
өдрийн хувьд давтагдахгүй дугаар).
Кассын системээр үүсгэгдэнэ.
rrn RRN  
Заавал  
Карт хүлээн авагч банкны гүйлгээ
лавлах дугаар
entryModeText Хэлбэр Заавал Карт уншуулсан хэлбэр
terminalId Terminal ID Заавал Банк терминал дугаар
merchantId Merchant ID Заавал Мерчант ID. Баримтад заавал хэвлэх
merchantName Дэлгүүрийн нэр Заавал Мерчант нэр. Баримтад заавал хэвлэх
cardHolderName  
Карт эзэмшигч  
Хэвлэж
болно  
Карт эзэмшигчийн нэр
transTime date Гүйлгээ
хийсэн
огноо
Гүйлгээний хариунд ирсэн банкны
огноог хэвлэнэ.  
loyaltyName loyaltyName Ирсэн бол
заавал
Урамшууллын нэр
noTxnAmount noTxnAmount Ирсэн бол
заавал
Урамшуулалгүй дүн
usableLp usableLp Ирсэн бол
заавал
Урамшууллын дүн
yesTxnAmount yesTxnAmount Ирсэн бол
заавал
Урамшуулал бодсон дүн

Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага
4.2 Өгөгдлийн сан үүсгэж хадгалах
JSON талбаруудыг Database руу хөрвүүлэх, амжилттай болсон гүйлгээг дараах бүтцээр хадгалж
болно.  
Талбар
Төрөл
Хэмжээ
merchantName
Тайлбар
varchar
50
merchantId
Мерчант нэр. Баримтад заавал хэвлэх
string
15
terminalId
Мерчант ID. Баримтад заавал хэвлэх
string
8
amount  
Банк Терминал дугаар
decimal(12,2)  
Нийт 12 оронтой бутархайн орон 2
орон. Гүйлгээний мөнгөн дүн.
(Гүйлгээний үнийн дүн 0-с дээш байна.
Бутархай тоог зөвшөөрнө. Бутархай
тооны нарийвчлал 2 орон. Жишээлбэл:
2530.66)  
traceNo  
varchar  
6  
Карт гаргагч банкны гүйлгээ шалгах
дугаар
dbRefNo  
varchar  
16  
ХСН талын хүсэлтийн дугаар (тухайн
өдрийн хувьд давтагдахгүй дугаар).  
batchNo
varchar
12
Settlement дугаар
authCode  
varchar  
6  
Амжилттай гүйлгээний зөвшөөрлийн
код
transTime
date  
Гүйлгээ хийсэн огноо
49
Лавлагаа
SA-100-2024
“EPOS SDK”
хэрэглэгчийн гарын авлага

50

4.3 Алдааны кодын тайлбар

Код Тайлбар/ENG/ Тайлбар
Банк
001 Authentication failed Баталгаажуулалт амжилтгүй
003 Invalid data Өгөгдөл буруу
005 Server error Серверийн алдаа
101 Card is expired Картын хүчинтэй хугацаа дууссан
116 Insufficient funds Үлдэгдэл хүрэлцэхгүй
117 Wrong PIN Пин код буруу
120 Not permitted Зөвшөөрөгдөөгүй үйлдэл
123 Card daily limit exceeded Картын өдрийн гүйлгээний лимит хэтэрсэн
200 Invalid card Хүчингүй карт
201 Card expired Картын хүчинтэй хугацаа дууссан
202 Invalid card Хүчингүй карт
204 Transaction limit reached Гүйлгээний лимит хэтэрсэн
205 Discarded transaction Татгалзсан гүйлгээ
206 Wrong PIN Пин код буруу
208 Blocked card Блоклогдсон карт
366 Customer cancelled Хэрэглэгч цуцалсан
396 Connection lost Холболт салсан
905 Connection failed Холболтын алдаа
914 Transaction to void not found Буцаалт хийх гүйлгээ олдсонгүй
915 Transaction to void has wrong amount Буцаалт хийх дүн буруу
