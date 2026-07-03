import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'add_medication_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<dynamic> _allMedications = [];
  List<dynamic> _filteredMedications = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';

  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredMedications = _allMedications.where((med) {
        final matchesSearch = query.isEmpty ||
            (med['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (med['category']?.toString().toLowerCase().contains(query) ??
                false);
        final matchesCategory = _selectedCategory == 'All' ||
            med['category'] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _loadMedications() async {
    try {
      final response = await ApiService.getMedications();
      if (response['status'] == 'success') {
        final meds = response['data']['medications'] as List;
        final cats = meds
            .map((m) => m['category']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        setState(() {
          _allMedications = meds;
          _filteredMedications = List.from(meds);
          _categories = ['All', ...cats];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('My Medications'),
        actions: [
          if (_allMedications.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredMedications.length} of ${_allMedications.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadMedications,
              child: _allMedications.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddMedicationScreen(),
            ),
          );
          _loadMedications();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medication',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSearchAndFilter()),
        if (_filteredMedications.isEmpty)
          SliverToBoxAdapter(child: _buildNoResults())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildMedicationCard(_filteredMedications[index]),
                childCount: _filteredMedications.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medications...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No medications match your search',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${med['dosage']} ${med['unit']} · ${med['form']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    med['category'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: med['is_active'] == true
                      ? AppColors.success
                      : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                med['is_active'] == true ? 'Active' : 'Inactive',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No medications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to add\nyour first medication',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
