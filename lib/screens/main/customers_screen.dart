import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../models/customer_model.dart';
import '../../models/locale_model.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/mnt_amount_formatter.dart';
import 'purchase_list_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, this.showAppBar = true});

  /// False when shown inside [MainScreen] (shell already shows [customers_title]).
  final bool showAppBar;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CustomerModel>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Consumer<LocaleModel>(
                builder: (context, localeModel, child) {
                  final l10n = AppLocalizations(localeModel.locale);
                  return Text(l10n.tr('customers_title'));
                },
              ),
              centerTitle: true,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search + register entry: fixed header, list gets remaining space.
          Consumer<LocaleModel>(
            builder: (context, localeModel, child) {
              final l10n = AppLocalizations(localeModel.locale);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        context.read<CustomerModel>().setSearchQuery(value);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: l10n.tr('search_customers'),
                        filled: true,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .deleteButtonTooltip,
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<CustomerModel>()
                                      .setSearchQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openCustomerRegisterSheet(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(l10n.tr('customer_register_section')),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),

          // Customer List
          Expanded(
            child: Consumer<CustomerModel>(
              builder: (context, customerModel, child) {
                if (customerModel.loadError != null && !customerModel.isLoading) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            customerModel.loadError!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => customerModel.refresh(),
                            child: const Text('Дахин ачаалах'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (customerModel.isLoading && customerModel.filteredCustomers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = customerModel.filteredCustomers;

                if (customers.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => customerModel.refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.35,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Consumer<LocaleModel>(
                                  builder: (context, localeModel, child) {
                                    final l10n =
                                        AppLocalizations(localeModel.locale);
                                    return Text(
                                      l10n.tr('no_customers'),
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => customerModel.refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return _CustomerCard(
                        customer: customer,
                        onTap: () => _showCustomerDetails(context, customer),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CustomerDetailsSheet(customer: customer),
    );
  }

  Future<void> _openCustomerRegisterSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: const _CustomerRegisterSheet(),
        );
      },
    );
  }
}

/// Харилцагч бүртгэх · `POST /khariltsagchBurtgeye` (modal body).
class _CustomerRegisterSheet extends StatefulWidget {
  const _CustomerRegisterSheet();

  @override
  State<_CustomerRegisterSheet> createState() => _CustomerRegisterSheetState();
}

class _CustomerRegisterSheetState extends State<_CustomerRegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ovog = TextEditingController();
  final _ner = TextEditingController();
  final _utas = TextEditingController();
  final _register = TextEditingController();
  final _mail = TextEditingController();
  final _khayag = TextEditingController();

  /// `ААН` | `Иргэн` — matches web [khariltsagchiinTurul].
  String _khariltsagchiinTurul = 'ААН';
  /// `Худалдан авагч` | `Нийлүүлэгч` | `Ажилтан` — matches web [turul].
  String _businessTurul = 'Худалдан авагч';
  bool _submitting = false;

  @override
  void dispose() {
    _ovog.dispose();
    _ner.dispose();
    _utas.dispose();
    _register.dispose();
    _mail.dispose();
    _khayag.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthModel>();
    if (auth.posSession == null) {
      showAppSnackBar(context, 'Салбарын сесс олдсонгүй',
          variant: AppSnackVariant.error);
      return;
    }
    final model = context.read<CustomerModel>();
    setState(() => _submitting = true);
    final msg = await model.registerCustomer(
      khariltsagchiinTurul: _khariltsagchiinTurul,
      turul: _businessTurul,
      ovog: _khariltsagchiinTurul == 'Иргэн' && _ovog.text.trim().isNotEmpty
          ? _ovog.text.trim()
          : null,
      ner: _ner.text.trim(),
      utas: _utas.text.trim(),
      register: _register.text.trim().isEmpty ? null : _register.text.trim(),
      mail: _mail.text.trim().isEmpty ? null : _mail.text.trim(),
      khayag: _khayag.text.trim().isEmpty ? null : _khayag.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (msg == null) {
      _ovog.clear();
      _ner.clear();
      _utas.clear();
      _register.clear();
      _mail.clear();
      _khayag.clear();
      showAppSnackBar(context, 'Амжилттай бүртгэгдлээ',
          variant: AppSnackVariant.success);
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      showAppSnackBar(context, msg, variant: AppSnackVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthModel>();

    return Material(
      color: colorScheme.surface,
      child: Consumer<LocaleModel>(
        builder: (context, localeModel, _) {
          final l10n = AppLocalizations(localeModel.locale);
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.tr('customer_register_section'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (auth.posSession == null)
                  Text(
                    'Салбарын сесс олдсонгүй',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.tr('customer_legal_type_heading'),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'Иргэн',
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(l10n.tr('customer_type_irgen')),
                              ),
                            ),
                            ButtonSegment(
                              value: 'ААН',
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(l10n.tr('customer_type_aan')),
                              ),
                            ),
                          ],
                          selected: {_khariltsagchiinTurul},
                          onSelectionChanged: (s) {
                            setState(() {
                              _khariltsagchiinTurul = s.first;
                              if (s.first == 'ААН') {
                                _ovog.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.tr('customer_business_turul_label'),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: const InputDecoration(
                            filled: true,
                            border: OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _businessTurul,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'Худалдан авагч',
                                  child: Text(
                                    l10n.tr('customer_turul_khudaldan'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Нийлүүлэгч',
                                  child: Text(
                                    l10n.tr('customer_turul_niiluulegch'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Ажилтан',
                                  child: Text(
                                    l10n.tr('customer_turul_ajiltan'),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _businessTurul = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_khariltsagchiinTurul == 'Иргэн') ...[
                          TextFormField(
                            controller: _ovog,
                            decoration: InputDecoration(
                              labelText: l10n.tr('customer_field_ovog'),
                              filled: true,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) {
                                return 'Овог оруулна уу';
                              }
                              if (val.length < 2) {
                                return 'Овог доод тал нь 2 үсэгтэй байна';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextFormField(
                          controller: _ner,
                          decoration: InputDecoration(
                            labelText: _khariltsagchiinTurul == 'Иргэн'
                                ? l10n.tr('customer_field_ner')
                                : 'Байгууллагын нэр',
                            filled: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) {
                              return _khariltsagchiinTurul == 'Иргэн'
                                  ? 'Нэр оруулна уу'
                                  : 'Байгууллагын нэр оруулна уу';
                            }
                            if (val.length < 2) {
                              return _khariltsagchiinTurul == 'Иргэн'
                                  ? 'Нэр доод тал нь 2 үсэгтэй байна'
                                  : 'Байгууллагын нэр доод тал нь 2 үсэгтэй байна';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _utas,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: l10n.tr('customer_field_utas'),
                            filled: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) {
                              return 'Утасны дугаар оруулна уу';
                            }
                            final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
                            if (digitsOnly.length < 8) {
                              return 'Утасны дугаар доод тал нь 8 оронтой тоо байна';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _register,
                          decoration: InputDecoration(
                            labelText: l10n.tr('customer_field_register'),
                            filled: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isNotEmpty && val.length < 7) {
                              return 'Регистрийн дугаар доод тал нь 7 оронтой байна';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: l10n.tr('customer_field_mail'),
                            filled: true,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isNotEmpty &&
                                (!val.contains('@') || !val.contains('.'))) {
                              return 'Зөв и-мэйл хаяг оруулна уу';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _khayag,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l10n.tr('customer_field_address'),
                            filled: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed:
                              _submitting ? null : () => _submit(context),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(l10n.tr('customer_register_save')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar + Name + Type Chip pushed to top-right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      customer.initialsLetter,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(type: customer.type),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatBadge(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Захиалга',
                    value: '${customer.totalPurchases} удаа',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  _StatBadge(
                    icon: Icons.payments_outlined,
                    label: 'Нийт зарцуулсан',
                    value: MntAmountFormatter.formatTugrikSpaced(
                        customer.totalSpent),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    isHighlight: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final CustomerType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    String label;

    switch (type) {
      case CustomerType.vip:
        color = Colors.amber;
        label = 'VIP';
        break;
      case CustomerType.corporate:
        color = colorScheme.secondary;
        label = 'Байгууллага';
        break;
      case CustomerType.individual:
        color = colorScheme.primary;
        label = 'Хувь хүн';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isHighlight;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      isHighlight ? colorScheme.primary : colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomerDetailsSheet extends StatelessWidget {
  final Customer customer;

  const CustomerDetailsSheet({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        customer.initialsLetter,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _TypeChip(type: customer.type),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Contact Info
                _SectionTitle(title: 'Холбогдох мэдээлэл'),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.phone,
                  label: 'Утас',
                  value: customer.phone,
                ),
                if (customer.email != null)
                  _InfoRow(
                    icon: Icons.email,
                    label: 'И-мэйл',
                    value: customer.email!,
                  ),
                if (customer.address != null)
                  _InfoRow(
                    icon: Icons.location_on,
                    label: 'Хаяг',
                    value: customer.address!,
                  ),
                const SizedBox(height: 24),

                // Stats
                _SectionTitle(title: 'Худалдан авалт'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Нийт захиалга',
                        value: '${customer.totalPurchases}',
                        icon: Icons.shopping_bag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Нийт зарцуулалт',
                        value: MntAmountFormatter.formatTugrik(customer.totalSpent),
                        icon: Icons.payments,
                      ),
                    ),
                  ],
                ),
                if (customer.creditLimit != null) ...[
                  const SizedBox(height: 12),
                  _StatCard(
                    title: 'Зээлийн лимит',
                    value: MntAmountFormatter.formatTugrik(customer.creditLimit!),
                    icon: Icons.credit_card,
                    subtitle:
                        'Үлдэгдэл: ${MntAmountFormatter.formatTugrik(customer.currentCredit ?? 0)}',
                  ),
                ],
                const SizedBox(height: 24),

                // Actions
                FilledButton.icon(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    final id = customer.id;
                    final name = customer.name;
                    nav.pop();
                    nav.push<void>(
                      MaterialPageRoute<void>(
                        builder: (ctx) => PurchaseListScreen(
                          khariltsagchiinId: id,
                          customerNameForTitle: name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: Text(AppLocalizations.of(context).tr('purchase_history')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      title,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.primary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
