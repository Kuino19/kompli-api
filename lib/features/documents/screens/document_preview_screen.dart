import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/pdf_service.dart';
import '../../ai_assistant/services/ai_service.dart';
import '../../../services/document_service.dart';
import '../../../services/billing_service.dart';
import '../../../core/widgets/premium_sheet.dart';
import '../widgets/signature_pad.dart';

class DocumentPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const DocumentPreviewScreen({super.key, required this.data});

  @override
  ConsumerState<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends ConsumerState<DocumentPreviewScreen> {
  late String _documentText;
  late String _documentTitle;
  bool _isSaving = false;
  bool _isExportingPdf = false;
  bool _isExportingDocx = false;
  Uint8List? _signatureBytes;

  @override
  void initState() {
    super.initState();
    _documentTitle = widget.data['title'] as String? ?? 'Document';
    _documentText =
        widget.data['content'] as String? ?? 'Error: No document content found.';
  }

  Future<void> _saveLocally() async {
    setState(() => _isSaving = true);
    await DocumentService().saveDocument(_documentTitle, _documentText);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Document saved!'),
          ]),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/');
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    await ExportService.exportPdf(
      title: _documentTitle,
      content: _documentText,
      context: context,
      signatureBytes: _signatureBytes,
    );
    if (mounted) setState(() => _isExportingPdf = false);
  }

  Future<void> _exportDocx() async {
    setState(() => _isExportingDocx = true);
    await ExportService.exportDocx(
      title: _documentTitle,
      content: _documentText,
      context: context,
    );
    if (mounted) setState(() => _isExportingDocx = false);
  }

  Future<void> _drawSignature() async {
    final result = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const SignaturePadDialog(),
    );
    if (result != null) {
      setState(() {
        _signatureBytes = result;
      });
      FirebaseAnalytics.instance.logEvent(
        name: 'document_signed',
        parameters: {'title': _documentTitle},
      );
    }
  }

  Future<void> _showTweakBottomSheet() async {
    final billing = BillingService();
    final isPremiumUser = await billing.isPremium();
    final credits = await billing.getCredits();
    final aiCredits = credits['ai'] ?? 0;

    if (!isPremiumUser && aiCredits <= 0) {
      if (!mounted) return;
      showPremiumUpgradeSheet(
        context,
        title: 'AI Customizer Locked',
        description: 'You have used all your free AI document edits. Subscribe to Premium for unlimited edits or buy an AI credit pack.',
        creditType: 'ai',
        onPurchaseSuccess: () {
          // Re-trigger bottom sheet open
          _showTweakBottomSheet();
        },
      );
      return;
    }

    final tweakController = TextEditingController();
    bool isTweaking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  const Text(
                    'Tweak Document with AI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Describe the changes you want to make (e.g. "change the lease duration to 2 years" or "add a section about penalties"). The AI will edit this document.',
                style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tweakController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your instructions here...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isTweaking
                      ? null
                      : () async {
                          final instructions = tweakController.text.trim();
                          if (instructions.isEmpty) return;

                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          setModalState(() => isTweaking = true);

                          try {
                            final prompt = '''The user wants to make modifications to the following legal document. Modify the document to incorporate their instructions. Return ONLY the modified document text starting directly with its title. Do not include any explanations, greetings, or conversational text.
                            
Instructions: $instructions

Original Document:
$_documentText''';

                            final aiService = ref.read(aiServiceProvider);
                            final response = await aiService.sendMessage(prompt);

                            if (response.startsWith('Both AI providers failed') ||
                                response.startsWith('An error occurred')) {
                              throw Exception('AI processing failed');
                            }

                            if (response.startsWith('⚠️ **AI Rate Limit Exceeded**')) {
                              throw Exception(response.replaceAll('⚠️ ', '').replaceAll('**', ''));
                            }

                            if (!isPremiumUser) {
                              await billing.consumeAiCredit();
                            }

                            if (mounted) {
                              setState(() {
                                _documentText = response;
                              });
                              FirebaseAnalytics.instance.logEvent(
                                name: 'document_tweaked',
                                parameters: {'title': _documentTitle},
                              );
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text('Document updated successfully!'),
                                    ],
                                  ),
                                  backgroundColor: AppTheme.primaryGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isTweaking = false);
                            final errorMsg = e.toString().contains('Rate Limit Exceeded')
                                ? e.toString().replaceAll('Exception:', '').trim()
                                : 'Failed to update document. Please try again.';
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isTweaking
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('AI is editing...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        )
                      : const Text('Tweak Document', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(_documentTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveLocally,
            tooltip: 'Save to Dashboard',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: MarkdownBody(
            data: _documentText,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                  fontSize: 15, height: 1.7, color: AppTheme.textDark),
              h1: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue),
              h2: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue),
              h3: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue),
              strong: const TextStyle(fontWeight: FontWeight.bold),
              blockquote: const TextStyle(
                  color: AppTheme.textLight, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ),

      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _signatureBytes != null ? Icons.verified : Icons.gesture,
                        color: _signatureBytes != null ? AppTheme.primaryGreen : AppTheme.textLight,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _signatureBytes != null ? 'Signature Added' : 'No Signature Added',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _signatureBytes != null ? AppTheme.primaryGreen : AppTheme.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _drawSignature,
                    icon: const Icon(Icons.draw, size: 16, color: AppTheme.primaryGreen),
                    label: Text(
                      _signatureBytes != null ? 'Change Signature' : 'Add E-Signature',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Customizer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyBlue,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showTweakBottomSheet,
                    icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.primaryGreen),
                    label: const Text(
                      'Tweak with AI',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],

      // Bottom action bar — Save | Export PDF | Export DOCX
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Save button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveLocally,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      foregroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Export PDF button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExportingPdf ? null : _exportPdf,
                    icon: _isExportingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf,
                            color: Colors.white, size: 18),
                    label: const Text('PDF',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE74C3C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Export DOCX button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExportingDocx ? null : _exportDocx,
                    icon: _isExportingDocx
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.article_outlined,
                            color: Colors.white, size: 18),
                    label: const Text('DOCX',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2980B9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
