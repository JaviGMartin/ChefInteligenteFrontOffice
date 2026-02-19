import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hogar.dart';
import '../services/auth_service.dart';
import '../services/hogar_service.dart';
import '../screens/login_screen.dart';
import '../screens/households_management_screen.dart';
import '../screens/inventory/global_pantry_screen.dart';
import '../screens/purchase_funnel_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/shopping_lists_screen.dart';
import '../screens/recipe_list_screen.dart';
import '../screens/kitchen_funnel_screen.dart';
import '../screens/team_management_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final ImagePicker _imagePicker = ImagePicker();
  Future<HogaresResult>? _hogaresFuture;
  bool _cambiandoHogar = false;

  @override
  void initState() {
    super.initState();
    AuthService().fetchUser(forceRefresh: true);
    _hogaresFuture = HogarService().fetchHogares();
    hogaresDataChangedNotifier.addListener(_onHogaresDataChanged);
  }

  @override
  void dispose() {
    hogaresDataChangedNotifier.removeListener(_onHogaresDataChanged);
    super.dispose();
  }

  void _onHogaresDataChanged() {
    if (mounted) {
      setState(() => _hogaresFuture = HogarService().fetchHogares());
    }
  }

  Future<void> _elegirHogarActivo(BuildContext context, int hogarId, HogaresResult result) async {
    if (result.hogarActivoId == hogarId) return;
    if (!result.puedeCambiarHogarActivo) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Con el plan Free solo puedes usar el hogar principal. Márcalo como principal en la web si quieres cambiarlo.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    setState(() => _cambiandoHogar = true);
    try {
      await HogarService().setHogarActivo(hogarId);
      if (!mounted) return;
      setState(() {
        _cambiandoHogar = false;
        _hogaresFuture = HogarService().fetchHogares();
      });
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hogar activo actualizado. Los datos se han refrescado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cambiandoHogar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAvatarSourceSheet(BuildContext context, AuthUser? user) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(context, ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, ImageSource source) async {
    try {
      final XFile? xFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xFile == null || !context.mounted) return;

      final Uint8List bytes = await xFile.readAsBytes();
      final String filename = xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg';
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo foto...')),
      );

      await AuthService().uploadAvatar(bytes, filename);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: Column(
        children: [
          ValueListenableBuilder<AuthUser?>(
            valueListenable: AuthService.userNotifier,
            builder: (context, user, _) {
              final name = user?.name ?? 'Usuario de prueba';
              final email = user?.email ?? '';
              final role = user?.role?.toLowerCase();
              final initial = name.isNotEmpty ? name.trim().toUpperCase()[0] : '?';
              final badge = _subscriptionBadge(role);
              const verdeBetis = Color(0xFF00914E);
              // Cabecera compacta: avatar + nombre + email + badge (sin línea redundante de hogar)
              const headerHeight = 100.0;
              return Container(
                height: headerHeight,
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      verdeBetis,
                      verdeBetis,
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Stack(
                  alignment: AlignmentDirectional.bottomStart,
                  clipBehavior: Clip.none,
                  children: [
                    // Capa inferior: degradado + textos
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (badge != null) badge,
                      ],
                    ),
                    // Capa superior: avatar opaco (imagen o inicial), tappable para cambiar foto
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        elevation: 2,
                        shadowColor: Colors.black38,
                        shape: const CircleBorder(),
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => _showAvatarSourceSheet(context, user),
                          customBorder: const CircleBorder(),
                          child: Builder(
                            builder: (context) {
                              final avatarUrl = user?.avatarUrl;
                              final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
                              return CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                backgroundImage: hasAvatar
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                                child: hasAvatar
                                    ? null
                                    : Text(
                                        initial,
                                        style: TextStyle(
                                          color: verdeBetis,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 28,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Selector de hogar activo (siempre visible, compacto, en blanco mientras carga)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hogar activo',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                FutureBuilder<HogaresResult>(
                  future: _hogaresFuture,
                  builder: (context, snapshot) {
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    final hasData = snapshot.hasData && snapshot.data!.hogares.isNotEmpty;
                    final result = snapshot.data;
                    final hogares = result?.hogares ?? [];
                    final hogarActivoId = result?.hogarActivoId;
                    final puedeCambiar = result?.puedeCambiarHogarActivo ?? false;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          value: hasData
                              ? ((hogarActivoId != null && hogares.any((h) => h.id == hogarActivoId))
                                  ? hogarActivoId
                                  : hogares.first.id)
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: primary.withOpacity(0.5)),
                            ),
                          ),
                          hint: Text(
                            isLoading ? 'Cargando…' : (snapshot.hasError ? 'Error al cargar' : (hasData ? '' : 'Sin hogares')),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          onChanged: (isLoading || _cambiandoHogar || !puedeCambiar || !hasData)
                              ? null
                              : (int? newId) {
                                  if (newId != null && result != null) {
                                    _elegirHogarActivo(context, newId, result);
                                  }
                                },
                          items: hogares
                              .map(
                                (h) => DropdownMenuItem<int>(
                                  value: h.id,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: h.esPrincipal
                                            ? Icon(
                                                Icons.star,
                                                size: 16,
                                                color: Colors.amber.shade700,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          h.nombre,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        if (hasData && !puedeCambiar)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Plan Free: solo hogar principal.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.person_outline, color: primary),
            title: Text('Mi Perfil', style: TextStyle(color: primary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          ExpansionTile(
            leading: Icon(Icons.home, color: primary),
            title: Text('Mi Hogar', style: TextStyle(color: primary)),
            children: [
              ListTile(
                leading: Icon(Icons.home_work, color: primary),
                title: Text('Mis Casas', style: TextStyle(color: primary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HouseholdsManagementScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.people_alt_outlined, color: primary),
                title: Text('Mi Equipo', style: TextStyle(color: primary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const TeamManagementScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.kitchen, color: primary),
                title: Text('Despensa', style: TextStyle(color: primary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const GlobalPantryScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.shopping_cart_outlined, color: primary),
                title: Text('Embudo de compra', style: TextStyle(color: primary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PurchaseFunnelScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.list_alt, color: primary),
                title: Text('Listas de compra', style: TextStyle(color: primary)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ShoppingListsScreen()),
                  );
                },
              ),
            ],
          ),
          ListTile(
            leading: Icon(Icons.restaurant, color: primary),
            title: Text('Recetas', style: TextStyle(color: primary)),
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RecipeListScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.filter, color: primary),
            title: Text('Planificador (Embudo)', style: TextStyle(color: primary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const KitchenFunnelScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.shoppingCart, color: primary),
            title: Text('Embudo de compra', style: TextStyle(color: primary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PurchaseFunnelScreen()),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: Icon(Icons.logout, color: primary),
            title: Text('Cerrar Sesión', style: TextStyle(color: primary)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget? _subscriptionBadge(String? role) {
    switch (role) {
      case 'gold':
        return const _Badge(
          label: 'Miembro Gold',
          icon: Icons.workspace_premium,
          color: Color(0xFFFFD54F),
        );
      case 'premium':
        return const _Badge(
          label: 'Miembro Premium',
          icon: Icons.star,
          color: Color(0xFF64B5F6),
        );
      case 'free':
      case 'gratis':
        return const _Badge(
          label: 'Miembro Free',
          icon: Icons.person,
          color: Colors.white70,
        );
      default:
        return null;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
