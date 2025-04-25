enum ClearStorageType {
  all('all'),
  bookmarks('bookmarks'),
  highlights('highlights'),
  currentBook('current-book');

  final String value;
  const ClearStorageType(this.value);
}
