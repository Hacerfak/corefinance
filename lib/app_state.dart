import 'package:flutter/material.dart';

class Empresa {
  final String id;
  final String nomeFantasia;
  final String cnpj;

  Empresa({required this.id, required this.nomeFantasia, required this.cnpj});

  factory Empresa.fromMap(Map<String, dynamic> map) {
    return Empresa(
      id: map['id'],
      nomeFantasia: map['nome_fantasia'],
      cnpj: map['cnpj'],
    );
  }

  // Necessário para o Dropdown comparar corretamente os objetos
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Empresa && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AppState {
  static final AppState _instancia = AppState._interno();
  factory AppState() => _instancia;
  AppState._interno();

  final ValueNotifier<List<Empresa>> empresasDisponiveis = ValueNotifier([]);
  // Restauramos a empresa ativa globalmente
  final ValueNotifier<Empresa?> empresaAtiva = ValueNotifier(null);
}
