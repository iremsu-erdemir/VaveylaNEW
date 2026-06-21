/// Ürün adı ve kategoriye göre tutarlı açıklama metni üretir.
String productDescriptionFor(ProductDescriptionInput input) {
  final name = input.name.trim().toLowerCase();
  final category = (input.categoryName ?? '').trim().toLowerCase();

  if (name.contains('börek') || name.contains('borek')) {
    return 'Taze pişirilmiş böreğimiz, ince yufka katmanları ve özenle hazırlanan iç harcıyla '
        'sıcak servis edilir. Kahvaltı ve ara öğünler için ideal bir hamur işi lezzetidir.';
  }
  if (name.contains('poğaça') ||
      name.contains('pogaca') ||
      name.contains('açma') ||
      name.contains('simit') ||
      name.contains('kruvasan') ||
      category.contains('hamur')) {
    return 'Günlük taze pişirilen hamur işlerimiz, tereyağlı dokusu ve zengin iç malzemeleriyle '
        'günün her saatine uygun pratik bir atıştırmalık sunar.';
  }
  if (name.contains('donut') || category.contains('donut')) {
    return 'Yumuşak hamuru ve üzerindeki glazür veya dolgusuyla hazırlanan donutlarımız, '
        'tatlı severler için hafif ve keyifli bir seçenektir.';
  }
  if (name.contains('kapkek') ||
      name.contains('cupcake') ||
      category.contains('kapkek')) {
    return 'Tek porsiyonluk kapkeklerimiz, kremalı ve meyveli çeşitleriyle özel günler ve '
        'günlük tatlı molaları için idealdir.';
  }
  if (name.contains('doğum') || category.contains('doğum günü')) {
    return 'Doğum günü pastalarımız, kişiye özel süsleme ve taze krema ile hazırlanır. '
        'Kutlamanızı unutulmaz kılar.';
  }
  if (name.contains('pasta') ||
      name.contains('tiramisu') ||
      name.contains('kadife') ||
      category.contains('pasta')) {
    return 'Şeflerimizin özenle hazırladığı pastalarımız, dengeli tatlılık ve zengin doku ile '
        'özel günlerinize lezzet katar.';
  }

  return '${input.name.trim()} — ${input.categoryName?.trim().isNotEmpty == true ? input.categoryName!.trim() : 'özel ürün'} '
      'kategorisinde, günlük taze malzemelerle hazırlanır.';
}

class ProductDescriptionInput {
  const ProductDescriptionInput({
    required this.name,
    this.categoryName,
  });

  final String name;
  final String? categoryName;
}
