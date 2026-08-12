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
}

class AppState {
  // Padrão Singleton para ter uma única instância em todo o app
  static final AppState _instancia = AppState._interno();
  factory AppState() => _instancia;
  AppState._interno();

  // Variável reativa que guarda a empresa atual
  final ValueNotifier<Empresa?> empresaAtiva = ValueNotifier<Empresa?>(null);

  // Lista de todas as empresas disponíveis para o menu
  final ValueNotifier<List<Empresa>> empresasDisponiveis = ValueNotifier([]);
}
