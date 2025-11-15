/// A generic class that handles pagination for lists
class PaginatedList<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final bool hasMore;
  final int totalItems;

  PaginatedList({
    required this.items,
    required this.page,
    required this.perPage,
    required this.hasMore,
    this.totalItems = 0,
  });

  /// Creates an empty paginated list
  factory PaginatedList.empty() => PaginatedList<T>(
        items: [],
        page: 0,
        perPage: 10,
        hasMore: false,
        totalItems: 0,
      );

  /// Creates a paginated list from a single page of items
  factory PaginatedList.singlePage(List<T> items) => PaginatedList<T>(
        items: items,
        page: 1,
        perPage: items.length,
        hasMore: false,
        totalItems: items.length,
      );

  /// Creates a new PaginatedList with updated values
  PaginatedList<T> copyWith({
    List<T>? items,
    int? page,
    int? perPage,
    bool? hasMore,
    int? totalItems,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      hasMore: hasMore ?? this.hasMore,
      totalItems: totalItems ?? this.totalItems,
    );
  }

  /// Appends new items to the current list
  PaginatedList<T> appendPage(List<T> newItems, {bool hasMore = false}) {
    final updatedItems = List<T>.from(items)..addAll(newItems);
    return copyWith(
      items: updatedItems,
      page: page + 1,
      hasMore: hasMore,
      totalItems: totalItems + newItems.length,
    );
  }

  /// Updates an item in the list
  PaginatedList<T> updateItem(T updatedItem, bool Function(T) test) {
    final index = items.indexWhere(test);
    if (index == -1) return this;
    
    final updatedItems = List<T>.from(items);
    updatedItems[index] = updatedItem;
    
    return copyWith(items: updatedItems);
  }

  /// Removes an item from the list
  PaginatedList<T> removeItem(bool Function(T) test) {
    final updatedItems = items.where((item) => !test(item)).toList();
    return copyWith(
      items: updatedItems,
      totalItems: totalItems - (items.length - updatedItems.length),
    );
  }

  /// Checks if the list is empty
  bool get isEmpty => items.isEmpty;

  /// Gets the current item count
  int get itemCount => items.length;

  /// Checks if there are more items to load
  bool get canLoadMore => hasMore;

  /// Gets the next page number to load
  int get nextPage => page + 1;
}
