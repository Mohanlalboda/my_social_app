import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenImageScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // బ్యాక్‌గ్రౌండ్ నల్లగా ఉంటే బాగుంటుంది
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${currentIndex + 1}/${widget.imageUrls.length}",
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: PhotoViewGallery.builder(
        itemCount: widget.imageUrls.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.imageUrls[index]), // నెట్‌వర్క్ ఇమేజ్
            initialScale: PhotoViewComputedScale.contained, // స్క్రీన్ కి సరిపోయేలా
            minScale: PhotoViewComputedScale.contained * 0.8, // కనీస స్కేల్
            maxScale: PhotoViewComputedScale.covered * 2, // గరిష్ట స్కేల్
            heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrls[index]), // హీరో యానిమేషన్
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: PageController(initialPage: widget.initialIndex), // మొదట ఏ పేజీ చూపాలో
        onPageChanged: (index) {
          setState(() => currentIndex = index); // పేజీ మారినప్పుడు ఇండెక్స్ అప్‌డేట్
        },
        scrollPhysics: const BouncingScrollPhysics(), // స్వైపింగ్ ఫిజిక్స్
      ),
    );
  }
}