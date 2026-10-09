import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'models/expense.dart';
import 'models/category_budget.dart';
import 'services/expense_database.dart'
    if (dart.library.html) 'services/expense_database_web.dart';
import 'services/receipt_ocr.dart'
    if (dart.library.html) 'services/receipt_ocr_web.dart';
import 'services/receipt_parser.dart';
import 'widgets/spending_painters.dart';

void main() => runApp(const ReceiptWiseApp());

class ReceiptWiseApp extends StatelessWidget {
  const ReceiptWiseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ReceiptWise',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7F5),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF235D4B)),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F7F5),
            foregroundColor: Color(0xFF18231F),
          ),
        ),
        home: const DashboardPage(),
      );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _categories = [
    'Food & drink',
    'Transport',
    'Shopping',
    'Health',
    'Other',
  ];

  List<Expense> _expenses = [];
  List<CategoryBudget> _budgets = [];
  bool _loading = true;
  bool _scanning = false;
  int? _selectedSlice;
  int? _selectedWeekday;
  String _searchQuery = '';
  String _categoryFilter = 'All';
  final ImagePicker _imagePicker = ImagePicker();
  final ReceiptOcr _receiptOcr = ReceiptOcr();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await ExpenseDatabase.instance.getAll();
    final budgets = await ExpenseDatabase.instance.getBudgets(DateTime.now());
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _budgets = budgets;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _receiptOcr.close();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null || !mounted) return;
      setState(() => _scanning = true);
      final text = await _receiptOcr.readText(image.path);
      if (!mounted) return;
      setState(() => _scanning = false);
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found. Try a clearer photo.')),
        );
        return;
      }
      await _addExpense(draft: ReceiptParser.parse(text));
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not scan receipt: $error')),
      );
    }
  }

  List<Expense> get _monthExpenses => _expenses
      .where((expense) =>
          expense.date.month == DateTime.now().month &&
          expense.date.year == DateTime.now().year)
      .toList();

  double get _monthTotal =>
      _monthExpenses.fold(0, (sum, expense) => sum + expense.amount);

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final expense in _monthExpenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  List<double> get _weekTotals {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    return List<double>.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      return _expenses
          .where((expense) =>
              expense.date.year == day.year &&
              expense.date.month == day.month &&
              expense.date.day == day.day)
          .fold<double>(0, (sum, expense) => sum + expense.amount);
    });
  }

  List<Expense> get _filteredExpenses {
    final query = _searchQuery.trim().toLowerCase();
    return _expenses.where((expense) {
      final matchesCategory =
          _categoryFilter == 'All' || expense.category == _categoryFilter;
      final matchesSearch = query.isEmpty ||
          expense.merchant.toLowerCase().contains(query) ||
          expense.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _selectWeekday(TapUpDetails details, double width) {
    final index =
        (details.localPosition.dx / (width / 7)).floor().clamp(0, 6).toInt();
    setState(() => _selectedWeekday = index);
  }

  Future<void> _editBudgets() async {
    final existing = {for (final budget in _budgets) budget.category: budget};
    final controllers = {
      for (final category in _categories)
        category: TextEditingController(
          text: existing[category]?.limit.toStringAsFixed(0) ?? '',
        ),
    };
    String? error;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Monthly budgets · ${DateFormat.yMMMM().format(DateTime.now())}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set a spending limit for each category. Leave a field blank to remove its limit.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF69756F)),
                ),
                const SizedBox(height: 12),
                for (final category in _categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controllers[category],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: category,
                        prefixText: '₫ ',
                      ),
                    ),
                  ),
                if (error != null)
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final invalid = controllers.entries.any((entry) {
                  final value = entry.value.text.trim();
                  return value.isNotEmpty &&
                      (double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) <= 0;
                });
                if (invalid) {
                  setDialogState(() => error = 'Enter a positive number or leave it blank.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save budgets'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      for (final category in _categories) {
        final text = controllers[category]!.text.trim();
        final amount = double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
        if (amount == null) {
          await ExpenseDatabase.instance.removeBudget(category, DateTime.now());
        } else {
          await ExpenseDatabase.instance.saveBudget(
            CategoryBudget(
              category: category,
              month: _monthKey(DateTime.now()),
              limit: amount,
            ),
          );
        }
      }
      await _loadExpenses();
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Widget _buildBudgetCard(NumberFormat currency) {
    final totals = _categoryTotals;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly budgets',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _editBudgets,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(_budgets.isEmpty ? 'Set limits' : 'Edit'),
              ),
            ],
          ),
          if (_budgets.isEmpty)
            const Text(
              'Set category limits to keep this month on track.',
              style: TextStyle(color: Color(0xFF84908B), fontSize: 12),
            )
          else
            ..._budgets.map((budget) {
              final spent = totals[budget.category] ?? 0;
              final progress = (spent / budget.limit).clamp(0.0, 1.0).toDouble();
              final over = spent > budget.limit;
              final color = over ? const Color(0xFFB84F42) : const Color(0xFF235D4B);
              return Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(budget.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        Text('${currency.format(spent)} / ${currency.format(budget.limit)}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE8EEEA),
                        color: color,
                      ),
                    ),
                    if (over)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('Over budget by ${currency.format(spent - budget.limit)}', style: const TextStyle(color: Color(0xFFB84F42), fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _selectSlice(TapUpDetails details, List<double> values) {
    final center = const Offset(75, 75);
    final point = details.localPosition - center;
    if (point.distance < 42 || point.distance > 78 || values.isEmpty) return;
    var angle =
        (point.direction + 3.141592653589793 / 2) % (2 * 3.141592653589793);
    if (angle < 0) angle += 2 * 3.141592653589793;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    for (var i = 0; i < values.length; i++) {
      angle -= values[i] / total * 2 * 3.141592653589793;
      if (angle <= 0) {
        setState(() => _selectedSlice = i);
        return;
      }
    }
    setState(() => _selectedSlice = values.length - 1);
  }

  Future<void> _addExpense({Expense? draft}) async {
    final merchantController = TextEditingController(text: draft?.merchant);
    final amountController = TextEditingController(
      text: draft == null ? '' : draft.amount.toStringAsFixed(0),
    );
    var selectedCategory =
        _categories.contains(draft?.category) ? draft!.category : 'Other';
    var selectedDate = draft?.date ?? DateTime.now();
    String? formError;
    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(draft == null ? 'Add expense' : 'Review receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: merchantController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Merchant'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                       const TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₫ ',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(
                    () => selectedCategory = value ?? selectedCategory,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(DateFormat.yMMMd().format(selectedDate)),
                  ),
                ),
                if (formError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final rawAmount =
                    amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final amount = double.tryParse(rawAmount);
                final merchant = merchantController.text.trim();
                if (merchant.isEmpty || amount == null || amount <= 0) {
                  setDialogState(() {
                    formError = 'Enter a merchant and a valid amount.';
                  });
                  return;
                }
                Navigator.pop(
                  context,
                  Expense(
                    merchant: merchant,
                    amount: amount,
                    date: selectedDate,
                    category: selectedCategory,
                  ),
                );
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );

    merchantController.dispose();
    amountController.dispose();

    if (result != null && mounted) {
      await ExpenseDatabase.instance.insert(result);
      await _loadExpenses();
    }
  }

  Widget _buildSpendingCharts(NumberFormat currency) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final categories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final values = categories.map((entry) => entry.value).toList();
    final selected =
        _selectedSlice != null && _selectedSlice! < categories.length
            ? categories[_selectedSlice!]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending breakdown · this month',
          style: TextStyle(
            color: Color(0xFF18231F),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTapUp: (details) => _selectSlice(details, values),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeOutCubic,
                        builder: (context, progress, child) => CustomPaint(
                          painter: CategoryDonutPainter(
                            values: values,
                            progress: progress,
                            selectedIndex: _selectedSlice,
                          ),
                          child: child,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(35),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  selected?.key ?? 'CATEGORIES',
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF84908B),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  selected == null
                                      ? '${categories.length}'
                                      : currency.format(selected.value),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    color: Color(0xFF18231F),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: categories.isEmpty
                        ? const Text(
                            'Add an expense to see your category totals.',
                            style: TextStyle(
                              color: Color(0xFF84908B),
                              fontSize: 12,
                            ),
                          )
                        : Column(
                            children: categories
                                .take(5)
                                .toList()
                                .asMap()
                                .entries
                                .map(
                                  (item) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: chartColors[
                                                item.key % chartColors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            item.value.key,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF18231F),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          currency.format(item.value.value),
                                          style: const TextStyle(
                                            color: Color(0xFF18231F),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'THIS WEEK',
                  style: TextStyle(
                    color: Color(0xFF84908B),
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedWeekday != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${DateFormat.EEEE().format(monday.add(Duration(days: _selectedWeekday!)))} · ${currency.format(_weekTotals[_selectedWeekday!])}',
                      style: const TextStyle(
                        color: Color(0xFF235D4B),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                height: 82,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _selectWeekday(details, constraints.maxWidth),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, child) => CustomPaint(
                        painter: WeekBarsPainter(
                          expenses: _expenses,
                          progress: progress,
                          selectedIndex: _selectedWeekday,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF235D4B)),
            SizedBox(width: 10),
            Text(
              'ReceiptWise',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add expense manually',
            onPressed: () => _addExpense(),
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF235D4B),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL SPENT THIS MONTH',
                        style: TextStyle(
                          color: Color(0xFFC7D9D0),
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        currency.format(_monthTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${_monthExpenses.length} purchases tracked',
                        style: const TextStyle(color: Color(0xFFE0EBE6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildBudgetCard(currency),
                if (kIsWeb)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF235D4B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Web demo: add expenses manually. Receipt scanning is available in the Android app.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _buildSpendingCharts(currency),
                const SizedBox(height: 27),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent expenses',
                        style: TextStyle(
                          color: Color(0xFF18231F),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loading || _scanning
                          ? null
                          : kIsWeb
                              ? () => _addExpense()
                              : _scanReceipt,
                      icon: Icon(
                        kIsWeb ? Icons.add : Icons.document_scanner_outlined,
                        size: 18,
                      ),
                      label: Text(kIsWeb ? 'Add' : 'Scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_expenses.isNotEmpty) ...[
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search merchant or category',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', ..._categories].map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _categoryFilter == category,
                            onSelected: (_) => setState(
                              () => _categoryFilter = category,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_filteredExpenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 38,
                          color: Color(0xFF789386),
                        ),
                        SizedBox(height: 10),
                        Text(
                          _expenses.isEmpty
                              ? 'No expenses yet'
                              : 'No matching expenses',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _expenses.isEmpty
                              ? 'Scan a receipt or add an expense manually.'
                              : 'Try another search or category filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF84908B), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ..._filteredExpenses.map(
                    (expense) => Dismissible(
                      key: ValueKey(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8E3DF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      onDismissed: (_) async {
                        final id = expense.id;
                        if (id != null) {
                          await ExpenseDatabase.instance.delete(id);
                          await _loadExpenses();
                        }
                      },
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 9),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F0EC),
                            child: Icon(Icons.storefront_outlined,
                                color: Color(0xFF235D4B)),
                          ),
                          title: Text(
                            expense.merchant,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${expense.category} · ${DateFormat.MMMd().format(expense.date)}',
                          ),
                          trailing: Text(
                            currency.format(expense.amount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _scanning
            ? null
            : kIsWeb
                ? () => _addExpense()
                : _scanReceipt,
        icon: !kIsWeb && _scanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(kIsWeb ? Icons.add : Icons.document_scanner_outlined),
        label: Text(kIsWeb
            ? 'Add expense'
            : _scanning
                ? 'Reading receipt…'
                : 'Scan receipt'),
      ),
    );
  }
}
