import 'package:mangayomi/bridge_lib.dart';
import 'dart:convert';

class ReAnime extends MProvider {
  ReAnime();

  @override
  String get name => "ReAnime.to";

  @override
  String get baseUrl => "https://api.reanime.to";

  @override
  Future<MPages> getPopularAnime(int page) async {
    // ReAnime API doesn't have a popular endpoint, using search as fallback
    final res = await http('GET', '$baseUrl/search?q=a');
    final data = jsonDecode(res);
    
    List<MManga> animeList = [];
    for (var item in data['results'] ?? []) {
      animeList.add(_parseAnime(item));
    }
    
    return MPages(animeList, false);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    // Using search for recent anime
    final res = await http('GET', '$baseUrl/search?q=new');
    final data = jsonDecode(res);
    
    List<MManga> animeList = [];
    for (var item in data['results'] ?? []) {
      animeList.add(_parseAnime(item));
    }
    
    return MPages(animeList, false);
  }

  @override
  Future<MPages> searchAnime(String query, int page, MFilterList filters) async {
    final res = await http('GET', '$baseUrl/search?q=${Uri.encodeComponent(query)}');
    final data = jsonDecode(res);
    
    List<MManga> animeList = [];
    for (var item in data['results'] ?? []) {
      animeList.add(_parseAnime(item));
    }
    
    return MPages(animeList, false);
  }

  MManga _parseAnime(Map<String, dynamic> item) {
    return MManga(
      name: item['title'] ?? 'Unknown',
      imageUrl: item['image'] ?? item['poster'] ?? '',
      link: item['slug'] ?? item['id'] ?? '',
      status: MStatus.unknown,
    );
  }

  @override
  Future<MManga> getAnimeDetails(String slug) async {
    // Get anime info from search result or construct details page
    final res = await http('GET', '$baseUrl/search?q=$slug');
    final data = jsonDecode(res);
    
    var anime = MManga();
    anime.name = data['results']?[0]?['title'] ?? slug;
    anime.imageUrl = data['results']?[0]?['image'] ?? '';
    anime.description = data['results']?[0]?['description'] ?? '';
    anime.status = MStatus.unknown;
    
    // Get episode list - ReAnime uses episode numbers
    int episodeCount = data['results']?[0]?['episodes']?['sub'] ?? 
                      data['results']?[0]?['episodeCount'] ?? 1;
    
    List<MManga> episodes = [];
    for (int i = 1; i <= episodeCount; i++) {
      episodes.add(MManga(
        name: 'Episode $i',
        link: '$slug/$i',
        imageUrl: '',
      ));
    }
    anime.chapters = episodes;
    
    return anime;
  }

  @override
  Future<List<MVideo>> getVideoList(String url) async {
    // url format: slug/episode
    final parts = url.split('/');
    final slug = parts[0];
    final episode = parts[1];
    
    // Get available servers
    final res = await http('GET', '$baseUrl/servers/$slug/$episode');
    final data = jsonDecode(res);
    
    List<MVideo> videos = [];
    
    // Process sub servers
    for (var server in data['sub'] ?? []) {
      final serverName = server['serverName'] ?? 'Unknown';
      final dataLink = server['dataLink'] ?? '';
      
      if (dataLink.isNotEmpty) {
        try {
          final streamRes = await http('GET', '$baseUrl/stream/from-link?link=${Uri.encodeComponent(dataLink)}');
          final streamData = jsonDecode(streamRes);
          
          final streamUrl = streamData['url'] ?? streamData['stream'] ?? '';
          if (streamUrl.isNotEmpty) {
            videos.add(MVideo(
              url: streamUrl,
              originalUrl: streamUrl,
              quality: '${serverName} (SUB)',
              headers: {
                'Referer': 'https://flixcloud.cc/',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.0'
              },
            ));
          }
        } catch (e) {
          // Skip failed streams
        }
      }
    }
    
    // Process dub servers
    for (var server in data['dub'] ?? []) {
      final serverName = server['serverName'] ?? 'Unknown';
      final dataLink = server['dataLink'] ?? '';
      
      if (dataLink.isNotEmpty) {
        try {
          final streamRes = await http('GET', '$baseUrl/stream/from-link?link=${Uri.encodeComponent(dataLink)}');
          final streamData = jsonDecode(streamRes);
          
          final streamUrl = streamData['url'] ?? streamData['stream'] ?? '';
          if (streamUrl.isNotEmpty) {
            videos.add(MVideo(
              url: streamUrl,
              originalUrl: streamUrl,
              quality: '${serverName} (DUB)',
              headers: {
                'Referer': 'https://flixcloud.cc/',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.0'
              },
            ));
          }
        } catch (e) {
          // Skip failed streams
        }
      }
    }
    
    return videos;
  }

  @override
  List<dynamic> getFilterList() {
    return [];
  }

  @override
  String get lang => "en";

  @override
  bool get supportsLatest => true;
}

ReAnime main() {
  return ReAnime();
}
