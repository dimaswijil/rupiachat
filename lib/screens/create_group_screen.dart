import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../models/user_model.dart';
import '../widgets/avatar_widget.dart';
import '../utils/colors.dart';

/// Screen untuk membuat grup baru dari kontak yang sudah pernah dichat
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _auth = AuthService();
  final _chat = ChatService();
  final _group = GroupService();

  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _creating = false;

  // Step: 0 = pilih kontak, 1 = isi detail grup
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final uid = await _auth.currentUid ?? '';
    final token = await _auth.currentToken ?? '';
    _chat.setToken(token);
    _group.setToken(token);

    final users = await _chat.getUsers(uid);

    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _allUsers
          .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
      } else {
        _selectedIds.add(uid);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama grup tidak boleh kosong'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _creating = true);

    final group = await _group.createGroup(
      name: name,
      memberIds: _selectedIds.toList(),
    );

    setState(() => _creating = false);

    if (group != null && mounted) {
      // Kembali ke chat list (navbar), bukan masuk ke grup chat langsung
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat grup'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_step == 1) {
                  setState(() => _step = 0);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _step == 0 ? 'Pilih Kontak' : 'Buat Grup Baru',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            actions: [
              if (_step == 0 && _selectedIds.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text(
                    'Lanjut',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RupiaColors.primary))
          : _step == 0
              ? _buildContactSelector(isDarkMode)
              : _buildGroupDetails(isDarkMode),
    );
  }

  // ── STEP 0: Pilih kontak ─────────────────────────────────
  Widget _buildContactSelector(bool isDarkMode) {
    return Column(
      children: [
        // Selected chips
        if (_selectedIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            color: isDarkMode ? RupiaColors.cardDark : Colors.white,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedIds.map((uid) {
                final user = _allUsers.firstWhere((u) => u.uid == uid);
                return Chip(
                  avatar: AvatarWidget(
                    name: user.name,
                    size: 24,
                    photoUrl: user.photoUrl,
                  ),
                  label: Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteIconColor: RupiaColors.textSecondary,
                  onDeleted: () => _toggleSelection(uid),
                  backgroundColor: isDarkMode
                      ? RupiaColors.bgDark
                      : RupiaColors.primary.withOpacity(0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ),

        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          color: isDarkMode ? RupiaColors.cardDark : Colors.white,
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterUsers,
              style: TextStyle(
                color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari kontak...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : RupiaColors.textHint,
                ),
                prefixIcon: const Icon(Icons.search, color: RupiaColors.primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Info text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Kontak',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                Text(
                  '${_selectedIds.length} dipilih',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RupiaColors.primary,
                  ),
                ),
            ],
          ),
        ),

        // Contact list
        Expanded(
          child: _filteredUsers.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada kontak',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final isSelected = _selectedIds.contains(user.uid);

                    return InkWell(
                      onTap: () => _toggleSelection(user.uid),
                      child: Container(
                        color: isDarkMode ? RupiaColors.bgDark : Colors.white,
                        margin: const EdgeInsets.only(bottom: 1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                AvatarWidget(
                                  name: user.name,
                                  photoUrl: user.photoUrl,
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: RupiaColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDarkMode
                                              ? RupiaColors.bgDark
                                              : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDarkMode
                                          ? Colors.white
                                          : RupiaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.phone ?? user.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.white54
                                          : RupiaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: RupiaColors.primary,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── STEP 1: Detail grup ──────────────────────────────────
  Widget _buildGroupDetails(bool isDarkMode) {
    final selectedUsers =
        _allUsers.where((u) => _selectedIds.contains(u.uid)).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Group icon
          Center(
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: RupiaColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group,
                    size: 40,
                    color: RupiaColors.primary,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: RupiaColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Group name input
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? RupiaColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _nameCtrl,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : RupiaColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Nama Grup',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white38 : RupiaColors.textHint,
                ),
                border: InputBorder.none,
                icon: const Icon(Icons.group, color: RupiaColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Members header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Anggota: ${selectedUsers.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : RupiaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selected members horizontal scroll
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selectedUsers.length,
              itemBuilder: (context, index) {
                final user = selectedUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          AvatarWidget(
                            name: user.name,
                            size: 52,
                            photoUrl: user.photoUrl,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                _toggleSelection(user.uid);
                                if (_selectedIds.isEmpty) {
                                  setState(() => _step = 0);
                                }
                              },
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white24
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: isDarkMode
                                      ? Colors.white
                                      : RupiaColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 60,
                        child: Text(
                          user.name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white70
                                : RupiaColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Create button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RupiaColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _creating ? null : _createGroup,
                child: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Buat Grup',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
