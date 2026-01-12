import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  Stream<User?> get user {
    return _supabase.auth.onAuthStateChange.map((data) {
      return data.session?.user;
    });
  }

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  Future<bool> signUp({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response.session == null;
    } on AuthException catch (e) {
      throw _mapSupabaseException(e);
    } catch (e) {
      throw Exception('Неизвестная ошибка регистрации');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _mapSupabaseException(e);
    } catch (e) {
      throw Exception('Неизвестная ошибка входа');
    }
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Exception _mapSupabaseException(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return Exception('Неверный email или пароль');
      case 'user_already_exists':
        return Exception('Пользователь с таким email уже существует');
      case 'weak_password':
        return Exception('Пароль слишком простой');
      default:
        return Exception(e.message);
    }
  }
}
