import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:win32/win32.dart';

import '../models/wallpaper_model.dart';
import '../providers/favourites_provider.dart';
import '../providers/preview_drawer_provider.dart';
import '../widgets/top_nav_button.dart';

/// ✅ Windows wallpaper constants
const int SPI_SETDESKWALLPAPER = 20;
const int SPIF_UPDATEINIFILE = 0x01;
const int SPIF_SENDWININICHANGE = 0x02;

/// ✅ FFI typedefs
typedef SystemParametersInfoNative = Bool Function(
    Uint32 uiAction, Uint32 uiParam, Pointer<Utf16> pvParam, Uint32 fWinIni);
typedef SystemParametersInfoDart = bool Function(
    int uiAction, int uiParam, Pointer<Utf16> pvParam, int fWinIni);

class WallpaperStudioPage extends ConsumerStatefulWidget {
  final String category;
  final List<WallpaperModel> wallpapers;

  const WallpaperStudioPage({
    super.key,
    required this.category,
    required this.wallpapers,
  });

  @override
  ConsumerState<WallpaperStudioPage> createState() =>
      _WallpaperStudioPageState();
}

class _WallpaperStudioPageState extends ConsumerState<WallpaperStudioPage> {
  int selectedIndex = 0;
  String _selectedRoute = '/browse';

  late final SystemParametersInfoDart _systemParametersInfo;

  @override
  void initState() {
    super.initState();

    // ✅ Load the native Windows API (only if on Windows)
    if (Platform.isWindows) {
      final user32 = DynamicLibrary.open('user32.dll');
      _systemParametersInfo = user32
          .lookup<NativeFunction<SystemParametersInfoNative>>(
              'SystemParametersInfoW')
          .asFunction<SystemParametersInfoDart>();
    }
  }

  /// 🖼️ Set the desktop wallpaper (Windows only)
  Future<void> _setWallpaper(String imagePath) async {
    if (!Platform.isWindows) {
      debugPrint('Wallpaper setting is supported on Windows only.');
      return;
    }

    final pathPtr = imagePath.toNativeUtf16();
    final result = _systemParametersInfo(
      SPI_SETDESKWALLPAPER,
      0,
      pathPtr,
      SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE,
    );
    calloc.free(pathPtr);

    if (result == false) {
      debugPrint('❌ Failed to set wallpaper.');
    } else {
      debugPrint('✅ Wallpaper successfully set!');
    }
  }

  void _onNavTap(String route) {
    if (_selectedRoute == route) return;
    setState(() => _selectedRoute = route);
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.wallpapers[selectedIndex];
    final favourites = ref.watch(favouritesProvider);
    final notifier = ref.read(favouritesProvider.notifier);
    final isFavourite = favourites.any((w) => w.id == selected.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 18, color: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Back to Categories',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.black54),
                  ),
                  const Spacer(),
                  TopNavButton(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: _selectedRoute == '/',
                    onTap: () => _onNavTap('/'),
                  ),
                  const SizedBox(width: 12),
                  TopNavButton(
                    icon: Icons.grid_view_rounded,
                    label: 'Browse',
                    selected: _selectedRoute == '/browse',
                    onTap: () => _onNavTap('/browse'),
                  ),
                  const SizedBox(width: 12),
                  TopNavButton(
                    icon: Icons.favorite_border,
                    label: 'Favourites',
                    selected: _selectedRoute == '/favourites',
                    onTap: () => _onNavTap('/favourites'),
                  ),
                  const SizedBox(width: 12),
                  TopNavButton(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    selected: _selectedRoute == '/settings',
                    onTap: () => _onNavTap('/settings'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFECECEC)),

            // 🧱 Main content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Grid
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: GridView.builder(
                              itemCount: widget.wallpapers.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.68,
                              ),
                              itemBuilder: (context, index) {
                                final wall = widget.wallpapers[index];
                                final selectedNow = selectedIndex == index;
                                final fav =
                                    favourites.any((w) => w.id == wall.id);

                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedIndex = index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: AssetImage(wall.image),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            color: selectedNow
                                                ? Colors.black.withOpacity(0.35)
                                                : Colors.black.withOpacity(0.2),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          left: 10,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                wall.title,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                widget.category,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: GestureDetector(
                                            onTap: () =>
                                                notifier.toggle(wall),
                                            child: Icon(
                                              Icons.favorite,
                                              color: fav
                                                  ? Colors.amber
                                                  : Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Preview
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin:
                          const EdgeInsets.only(top: 20, right: 30, bottom: 20),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Preview',
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: 220,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: AssetImage(selected.image),
                                  fit: BoxFit.cover,
                                ),
                                border:
                                    Border.all(color: Colors.black12, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(selected.title,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 18)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: selected.tags.map(_buildTag).toList(),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(selected.description,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      color: Colors.grey[700],
                                      height: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () => notifier.toggle(selected),
                            icon: Icon(
                              isFavourite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavourite
                                  ? Colors.amber
                                  : Colors.black54,
                            ),
                            label: Text(
                              isFavourite ? 'Saved' : 'Save to Favorites',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _setWallpaper(selected.image),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB23F),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text('Set Wallpaper',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Chip(
      label: Text(text,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
      backgroundColor: const Color(0xFFF1F1F1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }
}
