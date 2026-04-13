import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Login
      'login_title': 'Login',
      'login_button': 'Login',
      'username': 'Username',
      'username_hint': 'admin',
      'password': 'Password',
      'password_hint': 'Enter password',
      'forgot_password': 'Forgot Password?',
      'invalid_username': 'Please enter username',
      'invalid_username_or_password': 'Invalid username or password',
      'biometric_unavailable': 'Biometric not available',
      'biometric_failed': 'Biometric authentication failed',

      // 2FA
      'verify_2fa': 'Verify Code',
      'enter_2fa_code': 'Enter verification code',
      'code_sent_to': 'Code sent',
      'resend_code': 'Resend Code',
      'verify': 'Verify',
      'invalid_code': 'Invalid code',
      'code_error_length': 'Please enter all 6 digits',
      'resend_code': 'Resend',
      'didnt_receive_code': 'Didn\'t receive code?',
      'back_to_login': 'Back to Login',
      'code_resent': 'Code resent',

      // Forgot Password
      'forgot_title': 'Reset Password',
      'forgot_subtitle': 'Enter username. SMS code will be sent.',
      'send': 'Send',
      'username_not_found': 'Username not found. Please try again.',
      'sms_sent': 'SMS Sent',
      'sms_sent_subtitle': 'Reset code sent to',
      'back_to_login_button': 'Back to Login',
      'didnt_receive_sms': 'Didn\'t receive SMS? Try again',

      // Profile
      'profile_title': 'Profile',
      'name': 'Name',
      'username': 'Username',
      'member_since': 'Member Since',
      'security': 'Security',
      'two_factor': 'Two-Factor Auth',
      'biometric': 'Biometric Login',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'account': 'Account',
      'change_password': 'Change Password',
      'logout': 'Logout',
      'logout_confirm_title': 'Logout',
      'logout_confirm_message': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'profile_updated': 'Profile updated successfully',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_password': 'Confirm New Password',
      'passwords_dont_match': 'Passwords do not match',
      'password_changed': 'Password changed successfully',
      'change': 'Change',
      'edit': 'Edit',
      'save': 'Save',
      'app_version': 'POS Pro v1.0.0',

      // Language
      'language': 'Language',
      'english': 'English',
      'mongolian': 'Mongolian',

      // Bottom Nav
      'dashboard': 'Dashboard',
      'pos': 'POS',
      'inventory': 'Inventory',
      'history': 'History',

      // Dashboard
      'welcome': 'Welcome',
      'today': 'Today',
      'revenue': 'Revenue',
      'transactions': 'Transactions',
      'inventory_status': 'Inventory Status',
      'view_all': 'View All',
      'low_stock': 'Low Stock',
      'out_of_stock': 'Out of Stock',
      'recent_sales': 'Recent Sales',

      // Customers
      'customers_title': 'Customers',
      'search_customers': 'Search customers...',
      'no_customers': 'No customers found',
      'add_customer': 'Add Customer',
      'customer_details': 'Customer Details',
      'purchase_history': 'Purchase History',
      'total_spent': 'Total Spent',
      'orders': 'Orders',
      'credit_limit': 'Credit Limit',

      // POS
      'search_products': 'Search products or scan barcode...',
      'clear_cart': 'Clear Cart',
      'checkout': 'Checkout',
      'subtotal': 'Subtotal',
      'tax': 'Tax (10%)',
      'discount': 'Discount',
      'total': 'Total',
      'pay': 'Pay',
      'payment_method': 'Payment Method',
      'cash': 'Cash',
      'card': 'Card',
      'transfer': 'Transfer',
      'credit': 'Credit',
      'amount_received': 'Amount Received',
      'change': 'Change',
      'print_receipt': 'Print Receipt',
      'email_receipt': 'Email Receipt',
      'receipt': 'Receipt',

      // Inventory
      'products': 'Products',
      'add_product': 'Add Product',
      'edit_product': 'Edit Product',
      'product_name': 'Product Name',
      'category': 'Category',
      'price': 'Price',
      'cost_price': 'Cost Price',
      'stock': 'Stock',
      'min_stock': 'Min Stock',
      'barcode': 'Barcode',
      'sku': 'SKU',
      'unit': 'Unit',
      'piece': 'Piece',
      'kg': 'kg',
      'liter': 'liter',
      'meter': 'meter',
      'box': 'Box',
      'goods_receipt': 'Goods Receipt',
      'stock_adjustment': 'Stock Adjustment',
      'stock_transfer': 'Stock Transfer',
      'inventory_count': 'Inventory Count',

      // Reports
      'sales_report': 'Sales Report',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'best_sellers': 'Best Sellers',
      'slow_movers': 'Slow Movers',
      'profit_loss': 'Profit/Loss',
      'employee_performance': 'Employee Performance',

      // Settings
      'general_settings': 'General Settings',
      'company_info': 'Company Information',
      'branch_info': 'Branch Information',
      'payment_methods': 'Payment Methods',
      'tax_settings': 'Tax Settings',
      'printer_settings': 'Printer Settings',
      'user_management': 'User Management',
      'roles_permissions': 'Roles & Permissions',

      // Transactions
      'transaction_history': 'Transaction History',
      'receipt_number': 'Receipt #',
      'date': 'Date',
      'cashier': 'Cashier',
      'status': 'Status',
      'refund': 'Refund',
      'ebarimt': 'E-Barimt',
      'vat': 'VAT',
      'city_tax': 'City Tax',
      'no_sales': 'No sales yet',
      'quick_actions': 'Quick Actions',
      'new_sale': 'New Sale',
      'items': 'items',

      // POS Extended
      'tap_products': 'Tap products to add',
      'complete_sale': 'Complete Sale',
      'clear': 'Clear',
      'out_of_stock_short': 'Out of Stock',
      'left': 'left',

      // Inventory Extended
      'inventory_management': 'Inventory Management',
      'search_inventory': 'Search by name or ID...',
      'total_items': 'Total Items',
      'low_stock_count': 'Low Stock',
      'in_stock': 'In Stock',
      'restock': 'Restock',
      'quantity_to_add': 'Quantity to add',
      'delete_confirm': 'Delete Product?',
      'delete_message': 'Are you sure you want to delete',

      // Sales History
      'sales_history': 'Sales History',
      'no_sales_history': 'No sales recorded yet',
      'complete_sale_to_see': 'Complete a sale to see it here',
      'today_label': 'Today',
      'yesterday': 'Yesterday',
      'sale': 'Sale',
      'view_details': 'View Details',
      'sale_completed': 'Sale Completed',
      'items_count': 'items',
    },
    'mn': {
      // Login
      'login_title': 'Нэвтрэх',
      'login_button': 'Нэвтрэх',
      'username': 'Хэрэглэгчийн нэр',
      'username_hint': 'admin',
      'password': 'Нууц үг',
      'password_hint': 'Нууц үг оруулна уу',
      'forgot_password': 'Нууц үг сэргээх',
      'invalid_username': 'Хэрэглэгчийн нэр оруулна уу',
      'invalid_username_or_password': 'Хэрэглэгчийн нэр эсвэл нууц үг буруу',
      'biometric_unavailable': 'Хурууны хээ ашиглах боломжгүй',
      'biometric_failed': 'Хурууны хээ таарахгүй байна',

      // 2FA
      'verify_2fa': 'Код баталгаажуулах',
      'enter_2fa_code': 'Баталгаажуулах код оруулна уу',
      'code_sent_to': 'Код илгээгдсэн',
      'resend_code': 'Дахин илгээх',
      'verify': 'Баталгаажуулах',
      'invalid_code': 'Код буруу',
      'code_error_length': 'Бүх 6 оронтой оруулна уу',
      'resend_code': 'Дахин илгээх',
      'didnt_receive_code': 'Код ирээгүй юу?',
      'back_to_login': 'Нэвтрэх рүү буцах',
      'code_resent': 'Код дахин илгээгдлээ',

      // Forgot Password
      'forgot_title': 'Нууц үг сэргээх',
      'forgot_subtitle': 'Хэрэглэгчийн нэрээ оруулна уу. SMS код илгээнэ.',
      'forgot_subtitle': 'Утасны дугаараа оруулна уу. SMS код илгээнэ.',
      'send': 'Илгээх',
      'phone_not_found': 'Утасны дугаар олдсонгүй. Шалгаад дахин оролдоно уу.',
      'sms_sent': 'SMS илгээгдлээ',
      'sms_sent_subtitle': 'дугаар руу SMS илгээлээ. Кодыг оруулна уу.',
      'back_to_login_button': 'Нэвтрэх рүү буцах',
      'didnt_receive_sms': 'SMS ирээгүй юу? Дахин илгээх',

      // Profile
      'profile_title': 'Профайл',
      'name': 'Нэр',
      'phone': 'Утас',
      'member_since': 'Бүртгүүлсэн',
      'security': 'Аюулгүй байдал',
      'two_factor': '2-Алхамт Баталгаа',
      'biometric': 'Хурууны Хээ',
      'enabled': 'Идэвхтэй',
      'disabled': 'Идэвхгүй',
      'account': 'Бүртгэл',
      'change_password': 'Нууц үг солих',
      'logout': 'Гарах',
      'logout_confirm_title': 'Гарах',
      'logout_confirm_message': 'Та системээс гарахыг хүсэж байна уу?',
      'cancel': 'Болих',
      'profile_updated': 'Профайл шинэчлэгдлээ',
      'current_password': 'Одоогийн нууц үг',
      'new_password': 'Шинэ нууц үг',
      'confirm_password': 'Шинэ нууц үг давтах',
      'passwords_dont_match': 'Нууц үг таарахгүй байна',
      'password_changed': 'Нууц үг амжилттай солигдлоо',
      'change': 'Солих',
      'edit': 'Засах',
      'save': 'Хадгалах',
      'app_version': 'POS Pro v1.0.0 • Монгол хэл',

      // Language
      'language': 'Хэл',
      'english': 'English',
      'mongolian': 'Монгол',

      // Bottom Nav
      'dashboard': 'Хянах самбар',
      'pos': 'Борлуулалт',
      'inventory': 'Бараа материал',
      'history': 'Түүх',

      // Dashboard
      'welcome': 'Тавтай морил',
      'today': 'Өнөөдөр',
      'revenue': 'Орлого',
      'transactions': 'Гүйлгээ',
      'inventory_status': 'Барааны байдал',
      'view_all': 'Бүгдийг харах',
      'low_stock': 'Дуусах дөхсөн',
      'out_of_stock': 'Дууссан',
      'recent_sales': 'Сүүлийн борлуулалт',
      'no_sales': 'Борлуулалт байхгүй',
      'quick_actions': 'Хурдан үйлдэл',
      'new_sale': 'Шинэ борлуулалт',
      'items': 'ширхэг',

      // Customers
      'customers_title': 'Харилцагчид',
      'search_customers': 'Харилцагч хайх...',
      'no_customers': 'Харилцагч олдсонгүй',
      'add_customer': 'Харилцагч нэмэх',
      'customer_details': 'Харилцагчийн мэдээлэл',
      'purchase_history': 'Худалдан авалтын түүх',
      'total_spent': 'Нийт зарцуулалт',
      'orders': 'Захиалга',
      'credit_limit': 'Зээлийн лимит',

      // POS
      'point_of_sale': 'Борлуулалтын цэг',
      'search_products': 'Бараа хайх...',
      'current_sale': 'Одоогийн борлуулалт',
      'no_items': 'Бараа нэмээгүй',
      'tap_products': 'Бараа дээр дарна уу',
      'subtotal': 'Дүн',
      'tax': 'Татвар (10%)',
      'total': 'Нийт',
      'complete_sale': 'Борлуулалт дуусгах',
      'clear': 'Цэвэрлэх',
      'out_of_stock_short': 'Дууссан',
      'left': 'үлдлээ',
      'clear_cart': 'Сагс цэвэрлэх',
      'checkout': 'Тооцоо',
      'discount': 'Хөнгөлөлт',
      'pay': 'Төлөх',
      'payment_method': 'Төлбөрийн хэлбэр',
      'cash': 'Бэлэн мөнгө',
      'card': 'Карт',
      'transfer': 'Шилжүүлэг',
      'credit': 'Зээл',
      'amount_received': 'Хүлээн авсан',
      'change': 'Хариулт',
      'print_receipt': 'Баримт хэвлэх',
      'email_receipt': 'И-мэйл илгээх',
      'receipt': 'Баримт',

      // Inventory
      'inventory_management': 'Бараа удирдлага',
      'search_inventory': 'Нэр эсвэл кодоор хайх...',
      'total_items': 'Нийт бараа',
      'low_stock_count': 'Дуусах дөхсөн',
      'in_stock': 'Бэлэн',
      'restock': 'Нөөцлөх',
      'delete': 'Устгах',
      'add_product': 'Бараа нэмэх',
      'quantity_to_add': 'Нэмэх тоо хэмжээ',
      'delete_confirm': 'Бараа устгах уу?',
      'delete_message': 'Та устгахыг хүсэж байна уу',
      'products': 'Бараа бүтээгдэхүүн',
      'edit_product': 'Бараа засах',
      'product_name': 'Барааны нэр',
      'category': 'Ангилал',
      'price': 'Үнэ',
      'cost_price': 'Өртөг үнэ',
      'stock': 'Нөөц',
      'min_stock': 'Хамгийн бага нөөц',
      'barcode': 'Бар код',
      'sku': 'SKU код',
      'unit': 'Хэмжих нэгж',
      'piece': 'ш',
      'kg': 'кг',
      'liter': 'л',
      'meter': 'м',
      'box': 'хайрцаг',
      'goods_receipt': 'Бараа орлого',
      'stock_adjustment': 'Нөөц өөрчлөлт',
      'stock_transfer': 'Нөөц шилжүүлэг',
      'inventory_count': 'Нөөц тооллого',

      // Reports
      'sales_report': 'Борлуулалтын тайлан',
      'daily': 'Өдөрөөр',
      'weekly': 'Долоо хоногоор',
      'monthly': 'Сараар',
      'best_sellers': 'Хамгийн их борлуулалттай',
      'slow_movers': 'Удаан эргэлттэй',
      'profit_loss': 'Ашиг/хохирол',
      'employee_performance': 'Ажилтны гүйцэтгэл',

      // Settings
      'general_settings': 'Ерөнхий тохиргоо',
      'company_info': 'Байгууллагын мэдээлэл',
      'branch_info': 'Салбарын мэдээлэл',
      'payment_methods': 'Төлбөрийн хэлбэрүүд',
      'tax_settings': 'Татварын тохиргоо',
      'printer_settings': 'Принтерийн тохиргоо',
      'user_management': 'Хэрэглэгчийн удирдлага',
      'roles_permissions': 'Эрх болон зөвшөөрөл',

      // Transactions
      'transaction_history': 'Гүйлгээний түүх',
      'receipt_number': 'Баримтын №',
      'date': 'Огноо',
      'cashier': 'Кассчин',
      'status': 'Төлөв',
      'refund': 'Буцаалт',
      'ebarimt': 'E-Баримт',
      'vat': 'НӨАТ',
      'city_tax': 'Хотын татвар',

      // Sales History
      'sales_history': 'Борлуулалтын түүх',
      'no_sales_history': 'Борлуулалт бүртгэгдээгүй',
      'complete_sale_to_see': 'Борлуулалт хийгээд энд харах болно',
      'today_label': 'Өнөөдөр',
      'yesterday': 'Өчигдөр',
      'sale': 'Борлуулалт',
      'view_details': 'Дэлгэрэнгүй',
      'sale_completed': 'Борлуулалт амжилттай',
      'items_count': 'ширхэг',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String tr(String key) => get(key);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'mn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class LocaleModel extends ChangeNotifier {
  Locale _locale = const Locale('mn'); // Default to Mongolian

  Locale get locale => _locale;

  bool get isMongolian => _locale.languageCode == 'mn';
  bool get isEnglish => _locale.languageCode == 'en';

  void setLocale(Locale locale) {
    if (!AppLocalizations.delegate.isSupported(locale)) return;
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    if (isMongolian) {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('mn'));
    }
  }
}
