class TxItem {
  String name;
  double price;
  String category;
  double? probability; // null jika kategori dipilih/diubah manual

  TxItem(this.name, this.price, this.category, [this.probability]);

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'category': category,
        'probability': probability,
      };

  factory TxItem.fromJson(Map<String, dynamic> j) => TxItem(
        j['name'] as String,
        (j['price'] as num).toDouble(),
        j['category'] as String,
        (j['probability'] as num?)?.toDouble(),
      );
}
