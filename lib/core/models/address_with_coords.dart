/// Adres metni ve koordinatları. Müşteri teslimat adresi için kullanılır.
class AddressWithCoords {
  const AddressWithCoords({
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;
}
