import 'dart:async';

import 'package:debt_tracker/core/widgets/empty_state.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:debt_tracker/presentation/widgets/entry_card.dart';
import 'package:debt_tracker/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              return TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search titles and notes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          SearchResultsBody(query: _query),
        ],
      ),
    );
  }
}

class SearchResultsBody extends ConsumerWidget {
  const SearchResultsBody({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(entryRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    if (query.isEmpty) {
      return const EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Search your debts',
        message: 'Find titles and notes across your owed items.',
      );
    }

    return FutureBuilder<List<Entry>>(
      future: repository.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final results = snapshot.data ?? <Entry>[];
        if (results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results found',
              message: 'Try a different title or note keyword.',
            ),
          );
        }

        final sections = <EntryType, List<Entry>>{
          EntryType.owedToMe: results
              .where((entry) => entry.type == EntryType.owedToMe)
              .toList(),
          EntryType.owedByMe: results
              .where((entry) => entry.type == EntryType.owedByMe)
              .toList(),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Results',
              action: Text(
                '${results.length} matches',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final section in const [
              EntryType.owedToMe,
              EntryType.owedByMe,
            ])
              if (sections[section]!.isNotEmpty) ...[
                SectionHeader(title: section.label),
                const SizedBox(height: 10),
                ...sections[section]!.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EntryCard(
                      entry: entry,
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute(
                          child: EntryDetailsScreen(entryId: entry.id),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
          ],
        );
      },
    );
  }
}
