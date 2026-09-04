import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class SavedSearchesScreen extends StatefulWidget {
  const SavedSearchesScreen({super.key});

  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen> {
  static const _storageKey = 'phonek_saved_searches';
  List<String> _searches = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searches = prefs.getStringList(_storageKey) ?? const [];
      _loading = false;
    });
  }

  Future<void> _save(List<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, values);
    if (mounted) setState(() => _searches = values);
  }

  Future<void> _addSearch() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حفظ بحث جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'عبارة البحث',
            hintText: 'مثال: Samsung A73 أو iPhone 13',
          ),
          onSubmitted: (text) => Navigator.pop(dialogContext, text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    final search = value?.trim() ?? '';
    if (search.isEmpty || _searches.contains(search)) return;
    await _save([search, ..._searches]);
  }

  Future<void> _deleteSearch(String search) async {
    await _save(_searches.where((item) => item != search).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عمليات البحث المحفوظة'),
        actions: [
          IconButton(
            tooltip: 'حفظ بحث جديد',
            onPressed: _addSearch,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _searches.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد عمليات بحث محفوظة\nاضغط + لحفظ بحث تستخدمه كثيرًا.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final search = _searches[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.search, color: AppColors.gold),
                        title: Text(search),
                        trailing: IconButton(
                          tooltip: 'حذف',
                          onPressed: () => _deleteSearch(search),
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _searches.isEmpty ? FloatingActionButton(onPressed: _addSearch, child: const Icon(Icons.add)) : null,
    );
  }
}
