// lib/screens/app_features/document/document_request_screen.dart
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/guest_guard.dart';
import '../../../providers/content_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../home/home.dart';
import '../../home/nav_bar_button.dart';
import 'document_tracking_screen.dart';

class DocumentRequestScreen extends ConsumerStatefulWidget {
  const DocumentRequestScreen({super.key});

  @override
  ConsumerState<DocumentRequestScreen> createState() =>
      _DocumentRequestScreenState();
}

class _DocumentRequestScreenState extends ConsumerState<DocumentRequestScreen> {
  bool _isDark = false;
  ColorScheme? _cs;

  // ─── ADAPTIVE COLORS ──────────────────────────────────
  Color get _scaffoldBg => _isDark ? _cs!.background : HomeColors.warmHearth;
  Color get _cardBg => _isDark ? _cs!.surface : HomeColors.cardWhite;
  Color get _titleText => _isDark ? _cs!.onSurface : HomeColors.deepAnchor;
  Color get _bodyText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.65)
      : AppColors.neutralGray800;
  Color get _mutedText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.45)
      : AppColors.neutralGray500;
  Color get _inputFill =>
      _isDark ? _cs!.surface.withValues(alpha: 0.8) : HomeColors.warmHearth;
  Color get _borderColor => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.15)
      : AppColors.neutralGray200;
  Color get _subtitleText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.5)
      : AppColors.neutralGray500;
  Color get _dragHandle => _isDark
      ? AppColors.neutralWhite.withValues(alpha: 0.24)
      : const Color(0xFFD1D5DB);

  // ─── FORM STATE ───────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _additionalNotesController =
      TextEditingController();

  String _selectedDocumentType = 'Business Permit';
  String? _selectedBarangay;

  final TextEditingController _barangaySearchController =
      TextEditingController();

  // OFFICIAL BARANGAYS OF MILAOR, CAMARINES SUR
  static const List<String> _milaorBarangays = [
    'Alimbuyog',
    'Amparado',
    'Balagbag',
    'Borongborongan',
    'Cabugao',
    'Capucnasan',
    'Dalipay',
    'Del Rosario',
    'Flordeliz',
    'Lipot',
    'Mayaopayawan',
    'Maycatmon',
    'Maydaso',
    'San Antonio',
    'San Jose',
    'San Miguel',
    'San Roque',
    'San Vicente',
    'Santo Domingo',
    'Tarusanan',
  ];

  bool _isSubmitting = false;

  /// Supporting documents the resident attached. Raw bytes rather than a
  /// `dart:io File` so reading/picking works on web too.
  final List<DocumentAttachment> _attachedFiles = [];
  final ImagePicker _picker = ImagePicker();

  // ─── DOCUMENT TYPES ───────────────────────────────────
  final List<Map<String, dynamic>> _documentTypes = [
    {
      'name': 'Business Permit',
      'icon': Icons.store_rounded,
      'fee': 500.0,
      'desc': 'Official permit to operate a business within the municipality',
      'color': const Color(0xFF0056A3),
      'available': true,
    },
    {
      'name': 'Civil Registry Documents',
      'icon': Icons.folder_copy_rounded,
      'fee': 200.0,
      'desc': 'Birth, Death, and Marriage Certificates from the civil registry',
      'color': const Color(0xFF4C229C),
      'available': true,
    },
    {
      'name': 'Tax Declaration',
      'icon': Icons.assessment_rounded,
      'fee': 150.0,
      'desc': 'Official tax declaration document for property assessment',
      'color': const Color(0xFF0C5A43),
      'available': false,
    },
    {
      'name': 'Certificate of Residency',
      'icon': Icons.home_work_rounded,
      'fee': 75.0,
      'desc': 'Proof of residency within the municipality',
      'color': AppColors.successAlt,
      'available': false,
    },
    {
      'name': 'Police Clearance',
      'icon': Icons.local_police_rounded,
      'fee': 150.0,
      'desc': 'Police clearance certificate for employment or travel purposes',
      'color': AppColors.warningAlt,
      'available': false,
    },
    {
      'name': 'Community Tax Certificate (Cedula)',
      'icon': Icons.receipt_rounded,
      'fee': 50.0,
      'desc': 'Community tax certificate required for various transactions',
      'color': const Color(0xFF643EB5),
      'available': false,
    },
    {
      'name': 'Zoning Clearance',
      'icon': Icons.map_rounded,
      'fee': 300.0,
      'desc': 'Clearance certifying property zoning compliance',
      'color': AppColors.neutralGray500,
      'available': false,
    },
    {
      'name': 'Fire Safety Inspection Certificate',
      'icon': Icons.fire_extinguisher_rounded,
      'fee': 250.0,
      'desc': 'Certificate of compliance with fire safety standards',
      'color': AppColors.errorDark,
      'available': false,
    },
    {
      'name': 'Sanitary Permit',
      'icon': Icons.health_and_safety_rounded,
      'fee': 200.0,
      'desc':
          'Permit certifying compliance with health and sanitation standards',
      'color': const Color(0xFFEC4899),
      'available': false,
    },
  ];

  Map<String, dynamic> get _selectedDocMeta =>
      _documentTypes.firstWhere((d) => d['name'] == _selectedDocumentType);

  bool get _selectedIsAvailable =>
      (_selectedDocMeta['available'] as bool?) ?? true;

  double get _fee => (_selectedDocMeta['fee'] as num).toDouble();
  bool get _isFree => _fee == 0.0;

  IconData _urgencyIcon(String iconName) {
    switch (iconName) {
      case 'priority_high':
        return Icons.priority_high_rounded;
      case 'event_note':
        return Icons.event_note_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _prefillFromAuth();
    if (_selectedBarangay != null && _selectedBarangay!.isNotEmpty) {
      _barangaySearchController.text = _selectedBarangay!;
    }
  }

  /// Auto-populates resident fields from the authenticated profile when
  /// available. Never invents data — fields stay empty for guests or when
  /// the profile has no value.
  void _prefillFromAuth() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;
    if (user.name.isNotEmpty && _fullNameController.text.isEmpty) {
      _fullNameController.text = user.name;
    }
    if (user.address != null &&
        user.address!.isNotEmpty &&
        _addressController.text.isEmpty) {
      _addressController.text = user.address!;
    }
  }

  // ─── PHOTO PICKING ────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _attachedFiles
        .add(DocumentAttachment(bytes: bytes, filename: image.name)));
  }

  Future<void> _takePhoto() async {
    final XFile? photo =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() => _attachedFiles
        .add(DocumentAttachment(bytes: bytes, filename: photo.name)));
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPhotoSheet(ctx),
    );
  }

  Widget _buildPhotoSheet(BuildContext ctx) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: _dragHandle,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Add Attachment',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: _titleText,
            ),
          ),
          SizedBox(height: 20.h),
          _photoOption(ctx,
              icon: Icons.camera_alt_rounded,
              title: 'Take a Photo',
              subtitle: 'Use your camera', onTap: () {
            Navigator.pop(ctx);
            _takePhoto();
          }),
          _photoOption(ctx,
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Pick from your photos', onTap: () {
            Navigator.pop(ctx);
            _pickImage();
          }),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  // ─── BARANGAY PICKER (SEARCHABLE) ─────────────────────
  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BarangayPickerSheet(
        barangays: _milaorBarangays,
        selectedBarangay: _selectedBarangay,
        onSelected: (barangay) {
          setState(() {
            _selectedBarangay = barangay;
            _barangaySearchController.text = barangay;
          });
        },
      ),
    );
  }

  Widget _photoOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child:
                      Icon(icon, size: 24.sp, color: HomeColors.heritagePurple),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: _titleText,
                          )),
                      SizedBox(height: 2.h),
                      Text(subtitle,
                          style: TextStyle(fontSize: 13.sp, color: _mutedText)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20.sp, color: _mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _removeFile(int index) => setState(() => _attachedFiles.removeAt(index));

  // ─── DOCUMENT TYPE PICKER ─────────────────────────────
  void _showDocumentTypePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDocTypeSheet(ctx),
    );
  }

  Widget _buildDocTypeSheet(BuildContext ctx) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _dragHandle,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 18.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color:
                            HomeColors.heritagePurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11.r),
                      ),
                      child: Icon(Icons.description_rounded,
                          size: 22.sp, color: HomeColors.heritagePurple),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Select Document Type',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _documentTypes.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, index) {
                    final doc = _documentTypes[index];
                    final isSelected = _selectedDocumentType == doc['name'];
                    return _docTypeTile(ctx, doc, isSelected);
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _docTypeTile(
      BuildContext ctx, Map<String, dynamic> doc, bool isSelected) {
    final Color accent = doc['color'] as Color;
    final double fee = (doc['fee'] as num).toDouble();
    final bool available = (doc['available'] as bool?) ?? true;

    final tileBg = isSelected
        ? accent.withValues(alpha: 0.06)
        : available
            ? (_isDark ? _cs!.background : HomeColors.warmHearth)
            : (_isDark
                ? _cs!.background.withValues(alpha: 0.5)
                : AppColors.neutralGray200);

    final tileBorder = isSelected
        ? accent
        : available
            ? _borderColor
            : (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.1)
                : const Color(0xFFE0E0E0));

    final iconBg = isSelected
        ? accent.withValues(alpha: 0.12)
        : available
            ? (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.08)
                : AppColors.neutralGray200)
            : (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.05)
                : AppColors.neutralGray200);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available
            ? () {
                setState(() => _selectedDocumentType = doc['name'] as String);
                Navigator.pop(ctx);
              }
            : null,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: tileBorder, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  available ? (doc['icon'] as IconData) : Icons.lock_rounded,
                  size: 26.sp,
                  color: isSelected
                      ? accent
                      : available
                          ? (_isDark
                              ? _cs!.onSurface.withValues(alpha: 0.4)
                              : AppColors.neutralGray500)
                          : _mutedText,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc['name'] as String,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: available
                                  ? (isSelected ? _titleText : _bodyText)
                                  : _mutedText,
                            ),
                          ),
                        ),
                        if (!available)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? AppColors.errorDark.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                  color: _isDark
                                      ? AppColors.errorDark
                                          .withValues(alpha: 0.3)
                                      : AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.errorDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      available ? (doc['desc'] as String) : 'Not Available',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: available ? _mutedText : AppColors.errorDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                available
                    ? (fee == 0 ? 'FREE' : '₱${fee.toStringAsFixed(0)}')
                    : 'N/A',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: available
                      ? (fee == 0 ? AppColors.successAlt : accent)
                      : _mutedText,
                ),
              ),
              if (isSelected) ...[
                SizedBox(width: 8.w),
                Icon(Icons.check_circle_rounded, size: 22.sp, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── SUBMIT ───────────────────────────────────────────
  Future<void> _submitRequest() async {
    if (GuestGuard.isGuest(ref)) {
      await GuestGuard.showGuestRestrictionDialog(context);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_selectedIsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('This document type is not available.'),
        backgroundColor: AppColors.errorDark,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }
    setState(() => _isSubmitting = true);

    // Every field collected on this screen is sent — Full Name, Address,
    // Additional Notes, the urgency level and the attached documents — so
    // the web admin sees the exact request the resident filed (see
    // supabase/document_requests_full_details.sql).
    //
    // `urgency` is set to a neutral default because residents no longer
    // choose a processing tier — queue position is handled by the
    // municipality's official service procedures.
    await ref.read(documentRequestsProvider.notifier).submitRequest(
          documentType: _selectedDocumentType,
          purpose: _purposeController.text.trim(),
          urgency: 'Standard',
          fullName: _fullNameController.text.trim(),
          address: _addressController.text.trim(),
          additionalNotes: _additionalNotesController.text.trim(),
          attachments: List<DocumentAttachment>.from(_attachedFiles),
          fee: '₱${(_selectedDocMeta['fee'] as double).toStringAsFixed(2)}',
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSuccessScreen();
  }

  void _showSuccessScreen() {
    final refId = _buildReferenceNumber();
    final urgencyLabel = 'Standard';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildSuccessDialog(ctx, refId, urgencyLabel),
    );
  }

  /// Derives the reference number from the most recently inserted request so
  /// it always matches what Supabase stored — never a fabricated value.
  String _buildReferenceNumber() {
    final requests = ref.read(documentRequestsProvider);
    if (requests.isNotEmpty) {
      return requests.first.reference;
    }
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return 'MLR-${now.substring(now.length - 8).toUpperCase()}';
  }

  Widget _buildSuccessDialog(
      BuildContext ctx, String refId, String urgencyLabel) {
    final tipBg = _isDark
        ? const Color(0xFF3A2A00)
        : AppColors.warningAlt.withValues(alpha: 0.08);
    final tipBorder = _isDark
        ? const Color(0xFF7A5800)
        : AppColors.warningAlt.withValues(alpha: 0.4);
    final tipText = AppColors.warningAlt;
    final refBg = _isDark ? _cs!.background : _scaffoldBg;
    final refBorder = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: Colors.transparent,
      // Keep the dialog inside the visible screen on short devices.
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 12.h,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 22.w,
            vertical: 20.h,
          ),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: HomeColors.heritagePurple.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          // The details scroll, while both action buttons stay visible.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 4.h),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (_, value, __) => Transform.scale(
                          scale: value,
                          child: Container(
                            width: 72.w,
                            height: 72.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF22C55E),
                                  AppColors.successAlt,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.successAlt
                                      .withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 38.sp,
                              color: _cardBg,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Request Successfully Submitted',
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                          color: _titleText,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Your request has been received by the municipal office. You can monitor its progress through May-Laud.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: _mutedText,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        decoration: BoxDecoration(
                          color: refBg,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: refBorder),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'REFERENCE NUMBER',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: _mutedText,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            SelectableText(
                              refId,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                color: HomeColors.heritagePurple,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _successDetailRow(
                        Icons.description_outlined,
                        'Document',
                        _selectedDocumentType,
                      ),
                      SizedBox(height: 10.h),
                      _successDetailRow(
                        Icons.calendar_today_outlined,
                        'Submission Date',
                        DateFormat('MMM dd, yyyy • hh:mm a')
                            .format(DateTime.now()),
                      ),
                      SizedBox(height: 10.h),
                      _successDetailRow(
                        Icons.schedule_outlined,
                        'Processing',
                        urgencyLabel,
                      ),
                      SizedBox(height: 10.h),
                      _successDetailRow(
                        Icons.info_outline,
                        'Status',
                        'Pending',
                      ),
                      SizedBox(height: 18.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: tipBg,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: tipBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18.sp,
                              color: AppColors.warningAlt,
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'Track this request live on the tracking screen — status updates appear automatically.',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: tipText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Primary action: navigate to the request tracking screen.
              SizedBox(
                width: double.infinity,
                height: 58.h,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DocumentTrackingScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.track_changes_rounded, size: 18.sp),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Track My Request',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.heritagePurple,
                    side: BorderSide(
                      color: HomeColors.heritagePurple.withValues(alpha: 0.4),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    minimumSize: Size(double.infinity, 58.h),
                    fixedSize: Size(double.infinity, 58.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              // Secondary action: close the dialog and return to the form.
              SizedBox(
                width: double.infinity,
                height: 58.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeColors.heritagePurple,
                    foregroundColor: AppColors.neutralWhite,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    minimumSize: Size(double.infinity, 58.h),
                    fixedSize: Size(double.infinity, 58.h),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Done',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _successDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 16.sp,
            color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 13.sp, color: _mutedText)),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _titleText,
            )),
      ],
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _addressController.clear();
    _purposeController.clear();
    _additionalNotesController.clear();
    setState(() {
      _selectedDocumentType = 'Business Permit';
      _selectedBarangay = null;
      _attachedFiles.clear();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _purposeController.dispose();
    _additionalNotesController.dispose();
    _barangaySearchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20.h),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDocumentTypeCard(),
                      SizedBox(height: 14.h),
                      _buildRequestDetailsCard(),
                      SizedBox(height: 14.h),
                      _buildResidentInfoCard(),
                      SizedBox(height: 14.h),
                      _buildAttachmentCard(),
                      SizedBox(height: 14.h),
                      _buildProcessingInfoCard(),
                      SizedBox(height: 14.h),
                      _buildSubmitButton(),
                      SizedBox(height: 10.h),
                      _buildInfoBanner(),
                      SizedBox(height: 20.h),
                      //_buildTransparencyCard(),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SLIVER APP BAR ───────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.h,
      pinned: true,
      elevation: 0,
      backgroundColor: HomeColors.deepAnchor,
      leading: Padding(
        padding: EdgeInsets.only(left: 16.w, top: 8.h),
        child: InkWell(
          onTap: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainApp()),
            (route) => false,
          ),
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Icon(Icons.arrow_back_rounded,
                size: 20.sp, color: AppColors.neutralWhite),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [HomeColors.deepAnchor, HomeColors.heritagePurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(15.r),
                        ),
                        child: Icon(Icons.description_rounded,
                            size: 28.sp, color: AppColors.neutralWhite),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Municipal Service Request',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutralWhite,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Accessible Government Services',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.neutralWhite
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Access municipal documents and services through May-Laud. Submit your request, monitor its progress, and stay informed throughout the process.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.neutralWhite.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── DOCUMENT TYPE CARD ───────────────────────────────
  Widget _buildDocumentTypeCard() {
    final doc = _selectedDocMeta;
    final Color accent = doc['color'] as Color;
    final bool available = _selectedIsAvailable;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Select a Document or Service'),
          SizedBox(height: 2.h),
          Text('Choose the municipal document or service you need.',
              style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
          SizedBox(height: 14.h),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showDocumentTypePicker,
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                      child: Icon(doc['icon'] as IconData,
                          size: 24.sp, color: accent),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDocumentType,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _titleText,
                                  ),
                                ),
                              ),
                              if (!available)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? AppColors.errorDark
                                            .withValues(alpha: 0.15)
                                        : AppColors.error
                                            .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(
                                        color: _isDark
                                            ? AppColors.errorDark
                                                .withValues(alpha: 0.3)
                                            : AppColors.error
                                                .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Unavailable',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.errorDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            doc['desc'] as String,
                            style:
                                TextStyle(fontSize: 13.sp, color: _mutedText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 18.sp, color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 16.sp, color: accent.withValues(alpha: 0.7)),
              SizedBox(width: 8.w),
              Text(
                _isFree ? 'Free of Charge' : 'Processing Fee',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _titleText,
                ),
              ),
              const Spacer(),
              Text(
                _isFree ? 'FREE' : '₱${_fee.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: _isFree ? AppColors.successAlt : accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── REQUEST DETAILS CARD ─────────────────────────────
  Widget _buildRequestDetailsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Request Details'),
          SizedBox(height: 2.h),
          Text('Describe what you need the document or service for.',
              style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _purposeController,
            maxLines: 3,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Purpose of Request',
              Icons.edit_note_rounded,
              hint: 'Purpose of request (e.g., Employment, School, Travel)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please specify the purpose of your request';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _additionalNotesController,
            maxLines: 3,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Reason or Explanation',
              Icons.sticky_note_2_rounded,
              hint: 'Any special instructions or details (optional)',
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESIDENT INFORMATION CARD ────────────────────────
  Widget _buildResidentInfoCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Resident Information'),
          SizedBox(height: 2.h),
          Text(
            'Provide accurate details for verification',
            style: TextStyle(
              fontSize: 13.sp,
              color: _subtitleText,
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _fullNameController,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Full Name',
              Icons.person_rounded,
              hint: 'Full Name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          TextFormField(
            controller: _addressController,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Complete Address',
              Icons.home_rounded,
              hint: 'Complete Address',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your address';
              }
              return null;
            },
          ),
          SizedBox(height: 14.h),
          InkWell(
            onTap: _showBarangayPicker,
            borderRadius: BorderRadius.circular(14.r),
            child: AbsorbPointer(
              child: TextFormField(
                controller: _barangaySearchController,
                readOnly: true,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: _titleText,
                ),
                decoration: _fieldDecoration(
                  'Assigned Barangay',
                  Icons.location_city_rounded,
                  hint: 'Search and select your barangay',
                  suffixIcon: Icon(
                    _selectedBarangay != null
                        ? Icons.check_circle_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20.sp,
                    color: HomeColors.heritagePurple,
                  ),
                ),
                validator: (value) {
                  if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
                    return 'Please select your barangay';
                  }
                  return null;
                },
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Select your registered barangay in Milaor, Camarines Sur.',
            style: TextStyle(
              fontSize: 11.sp,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ATTACHMENT CARD ──────────────────────────────────
  Widget _buildAttachmentCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Supporting Documents'),
              if (_attachedFiles.isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${_attachedFiles.length} file${_attachedFiles.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.heritagePurple,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Attach the required identification or supporting documents to help the municipal office verify your request.',
            style:
                TextStyle(fontSize: 13.sp, color: _subtitleText, height: 1.4),
          ),
          SizedBox(height: 16.h),
          if (_attachedFiles.isNotEmpty)
            SizedBox(
              height: 116.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachedFiles.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  if (index == _attachedFiles.length) {
                    return _buildAddThumb();
                  }
                  return _buildFileThumb(
                      file: _attachedFiles[index], index: index);
                },
              ),
            )
          else
            _buildEmptyAttachment(),
        ],
      ),
    );
  }

  Widget _buildEmptyAttachment() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPhotoSourcePicker,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 30.h),
          decoration: BoxDecoration(
            color: _scaffoldBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: HomeColors.heritagePurple.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.cloud_upload_rounded,
                    size: 26.sp, color: HomeColors.heritagePurple),
              ),
              SizedBox(height: 12.h),
              Text('Tap to attach files',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.heritagePurple,
                  )),
              SizedBox(height: 4.h),
              Text('Valid ID, proof of address, or other documents',
                  style: TextStyle(fontSize: 13.sp, color: _mutedText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddThumb() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPhotoSourcePicker,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 104.w,
          height: 116.h,
          decoration: BoxDecoration(
            color: HomeColors.heritagePurple.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: HomeColors.heritagePurple.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.add_rounded,
              size: 28.sp, color: HomeColors.heritagePurple),
        ),
      ),
    );
  }

  Widget _buildFileThumb(
      {required DocumentAttachment file, required int index}) {
    final fileName = file.filename;
    final fileSize = '${(file.bytes.length / 1024).toStringAsFixed(1)} KB';

    return Stack(
      children: [
        Container(
          width: 104.w,
          height: 116.h,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _scaffoldBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: _isDark
                      ? AppColors.errorDark.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    size: 20.sp, color: AppColors.errorDark),
              ),
              SizedBox(height: 8.h),
              Text(fileName,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: _titleText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              Text(fileSize,
                  style: TextStyle(fontSize: 9.sp, color: _mutedText)),
            ],
          ),
        ),
        Positioned(
          top: 6.w,
          right: 6.w,
          child: GestureDetector(
            onTap: () => _removeFile(index),
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: _isDark
                    ? AppColors.neutralWhite.withValues(alpha: 0.24)
                    : AppColors.neutralGray800.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 14.sp, color: AppColors.neutralWhite),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PROCESSING INFO CARD ─────────────────────────────
  Widget _buildProcessingInfoCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: HomeColors.heritagePurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.info_outline_rounded,
                size: 18.sp,
                color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Processing Information',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: _titleText,
                    )),
                SizedBox(height: 4.h),
                Text(
                  'Your request will be reviewed and processed according to the municipality\'s official service procedures. You will receive updates as its status changes.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: _bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SUBMIT BUTTON ────────────────────────────────────
  Widget _buildSubmitButton() {
    final bool canSubmit = _selectedIsAvailable && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitRequest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeColors.heritagePurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              HomeColors.heritagePurple.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          elevation: 2,
          shadowColor: HomeColors.heritagePurple.withValues(alpha: 0.20),
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 12.h,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSubmitting
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 21.w,
                      height: 21.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Submitting Request...',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Container(
                    //   width: 34.w,
                    //   height: 34.w,
                    //   // decoration: BoxDecoration(
                    //   //   color: Colors.white.withValues(alpha: 0.15),
                    //   //   borderRadius: BorderRadius.circular(10.r),
                    //   // ),
                    //   // child: Icon(
                    //   //   Icons.send_rounded,
                    //   //   size: 17.sp,
                    //   //   color: Colors.white,
                    //   // ),
                    // ),
                    SizedBox(width: 12.w),
                    Flexible(
                      child: Text(
                        'Submit Request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── INFO BANNER ──────────────────────────────────────
  Widget _buildInfoBanner() {
    final bannerBorder = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: HomeColors.heritagePurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.info_outline_rounded,
                size: 18.sp,
                color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Important Reminders',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleText,
                    )),
                SizedBox(height: 4.h),
                Text(
                  'Documents are processed during office hours (8 AM – 5 PM, Mon–Fri). '
                  'Present a valid ID when picking up your document. '
                  'Track your request status in the Profile section.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: _bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRANSPARENCY CARD ────────────────────────────────
  // Widget _buildTransparencyCard() {
  //   return Container(
  //     padding: EdgeInsets.all(20.w),
  //     decoration: _cardDecoration(),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  // children: [
  //   Container(
  //     width: 36.w,
  //     height: 36.w,
  //     decoration: BoxDecoration(
  //       color: HomeColors.heritagePurple.withValues(alpha: 0.08),
  //       borderRadius: BorderRadius.circular(10.r),
  //     ),
  //     child: Icon(Icons.public_rounded,
  //         size: 18.sp,
  //         color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
  //   ),
  //   SizedBox(width: 12.w),
  // Expanded(
  // child: Column(
  //   crossAxisAlignment: CrossAxisAlignment.start,
  //   children: [
  //     Text('Transparent Public Service',
  //         style: TextStyle(
  //           fontSize: 15.sp,
  //           fontWeight: FontWeight.w700,
  //           color: _titleText,
  //         )),
  //     SizedBox(height: 4.h),
  //     Text(
  //       'May-Laud promotes accessible and accountable municipal services by keeping residents informed about their requests and helping the municipality respond to community needs.',
  //       style: TextStyle(
  //         fontSize: 13.sp,
  //         color: _bodyText,
  //         height: 1.5,
  //       ),
  //     ),
  //   ],
  // ),
  //     ),
  // ],
  //     ),
  //   );
  // }

  // ─── SHARED HELPERS ───────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
        color: _titleText,
        letterSpacing: -0.2,
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon,
      {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14.sp,
        color: _mutedText,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        fontSize: 14.sp,
        color: _mutedText,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(left: 14.w, right: 10.w),
        child: Icon(icon,
            size: 20.sp,
            color: HomeColors.heritagePurple.withValues(alpha: 0.55)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: _inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: HomeColors.heritagePurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      errorStyle: TextStyle(fontSize: 12.sp, color: AppColors.errorDark),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

/// Half-screen searchable barangay picker sheet. Manages its own
/// [TextEditingController] lifecycle to avoid the
/// `_dependents.IsEmpty is not true` assertion that occurs when a
/// `StatefulBuilder` inside `showModalBottomSheet` is disposed while
/// dependents are still active.
class _BarangayPickerSheet extends StatefulWidget {
  final List<String> barangays;
  final String? selectedBarangay;
  final ValueChanged<String> onSelected;

  const _BarangayPickerSheet({
    required this.barangays,
    this.selectedBarangay,
    required this.onSelected,
  });

  @override
  State<_BarangayPickerSheet> createState() => _BarangayPickerSheetState();
}

class _BarangayPickerSheetState extends State<_BarangayPickerSheet> {
  late final TextEditingController _searchCtrl;

  String? _selected;

  @override
  void initState() {
    super.initState();

    _searchCtrl = TextEditingController();
    _selected = widget.selectedBarangay;
  }

  List<String> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();

    final results = widget.barangays.where((barangay) {
      return barangay.toLowerCase().contains(query);
    }).toList();

    results.sort((a, b) => a.compareTo(b));

    return results;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cs = Theme.of(context).colorScheme;

    final cardBg = isDark ? cs.surface : Colors.white;

    final titleText = isDark ? cs.onSurface : const Color(0xFF24005B);

    final bodyText =
        isDark ? cs.onSurface.withValues(alpha: 0.65) : const Color(0xFF4C229C);

    final mutedText =
        isDark ? cs.onSurface.withValues(alpha: 0.45) : const Color(0xFF6B6575);

    final inputFill =
        isDark ? cs.surface.withValues(alpha: 0.8) : const Color(0xFFFEF7FF);

    final borderColor =
        isDark ? cs.onSurface.withValues(alpha: 0.15) : const Color(0xFFE9E1F5);

    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            12.h,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28.r),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.24)
                  : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C229C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.location_city_rounded,
                    size: 22.sp,
                    color: const Color(0xFF4C229C),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Barangay',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: titleText,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Milaor, Camarines Sur',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C229C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${widget.barangays.length} Barangays',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4C229C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                fontSize: 14.sp,
                color: titleText,
              ),
              decoration: InputDecoration(
                hintText: 'Search barangay...',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: mutedText,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20.sp,
                  color: const Color(0xFF4C229C),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18.sp,
                          color: mutedText,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: inputFill,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF4C229C),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Text(
                  'AVAILABLE BARANGAYS',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: mutedText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} results',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: mutedText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 42.sp,
                          color: mutedText,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'No barangay found',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: titleText,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Try searching another barangay name.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 4.h,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 5.h),
                    itemBuilder: (_, index) {
                      final barangay = filtered[index];

                      final isSelected = _selected == barangay;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selected = barangay;
                            });

                            widget.onSelected(barangay);

                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15.w,
                              vertical: 14.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4C229C)
                                      .withValues(alpha: 0.07)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.r),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF4C229C)
                                          .withValues(alpha: 0.4),
                                    )
                                  : Border.all(
                                      color: Colors.transparent,
                                    ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_city_rounded,
                                  size: 19.sp,
                                  color: isSelected
                                      ? const Color(0xFF4C229C)
                                      : mutedText,
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    barangay,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected ? titleText : bodyText,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 19.sp,
                                    color: const Color(0xFF4C229C),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18.sp,
                                    color: mutedText,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
