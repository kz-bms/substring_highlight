library substring_highlight;

import 'dart:io';

import 'package:flutter/material.dart';

final int __int64MaxValue = double.maxFinite.toInt();

/// Widget that renders a string with sub-string highlighting.
class SubstringHighlight extends StatelessWidget {
  SubstringHighlight(
      {this.caseSensitive = false,
      this.maxLines,
      this.overflow = TextOverflow.clip,
      this.term,
      this.terms,
      required this.text,
      this.textAlign = TextAlign.left,
      this.textStyle = const TextStyle(
        color: Colors.black,
      ),
      this.textStyleHighlight = const TextStyle(
        color: Colors.red,
      ),
      this.wordDelimiters = ' .,;?!<>[]~`@#\$%^&*()+-=|\/_',
      this.words =
          false // default is to match substrings (hence the package name!)

      })
      : assert(term != null || terms != null);

  /// By default the search terms are case insensitive.  Pass false to force case sensitive matches.
  final bool caseSensitive;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  /// An optional maximum number of lines for the text to span, wrapping if necessary.
  /// If the text exceeds the given number of lines, it will be truncated according
  /// to [overflow].
  ///
  /// If this is 1, text will not wrap. Otherwise, text will be wrapped at the
  /// edge of the box.
  final int? maxLines;

  /// The sub-string that is highlighted inside {SubstringHighlight.text}.  (Either term or terms must be passed.  If both are passed they are combined.)
  final String? term;

  /// The array of sub-strings that are highlighted inside {SubstringHighlight.text}.  (Either term or terms must be passed.  If both are passed they are combined.)
  final List<String>? terms;

  /// The String searched by {SubstringHighlight.term} and/or {SubstringHighlight.terms} array.
  final String text;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// The {TextStyle} of the {SubstringHighlight.text} that isn't highlighted.
  final TextStyle textStyle;

  /// The {TextStyle} of the {SubstringHighlight.term}/{SubstringHighlight.ters} matched.
  final TextStyle textStyleHighlight;

  /// String of characters that define word delimiters if {words} flag is true.
  final String wordDelimiters;

  /// If true then match complete words only (instead of characters or substrings within words).  This feature is in ALPHA... use 'words' AT YOUR OWN RISK!!!
  final bool words;

  final RegExp regexEmoji = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])');

  Map<String, TextStyle> textStylePattern = {
    r'_(.*?)\_': const TextStyle(
      fontStyle: FontStyle.italic,
    ),
    r'\*(.*?)\*': const TextStyle(
      fontWeight: FontWeight.bold,
    ),
    /* r'\~(.*?)\~': const TextStyle(
      decoration: TextDecoration.lineThrough,
    ),*/
  };

  bool isBold = false;
  bool isItalic = false;

  @override
  Widget build(BuildContext context) {
    final String textLC = caseSensitive ? text : text.toLowerCase();

    // corner case: if both term and terms array are passed then combine
    final List<String> termList = [term ?? '', ...(terms ?? [])];

    // remove empty search terms ('') because they cause infinite loops
    final List<String> termListLC = termList
        .where((s) => s.isNotEmpty)
        .map((s) => caseSensitive ? s : s.toLowerCase())
        .toList();

    List<InlineSpan> children = [];

    int start = 0;
    int idx = 0; // walks text (string that is searched)
    while (idx < textLC.length) {
      // print('=== idx=$idx');

      nonHighlightAdd(int end) {
        return children
            .add(TextSpan(children: getTextStyle(text.substring(start, end))));
      }

      // find index of term that's closest to current idx position
      int iNearest = -1;
      int idxNearest = __int64MaxValue;
      for (int i = 0; i < termListLC.length; i++) {
        // print('*** i=$i');
        int at;
        if ((at = textLC.indexOf(termListLC[i], idx)) >= 0) //MAGIC//CORE
        {
          // print('idx=$idx i=$i at=$at => FOUND: ${termListLC[i]}');

          if (words) {
            if (at > 0 &&
                !wordDelimiters.contains(
                    textLC[at - 1])) // is preceding character a delimiter?
            {
              // print('disqualify preceding: idx=$idx i=$i');
              continue; // preceding character isn't delimiter so disqualify
            }

            int followingIdx = at + termListLC[i].length;
            if (followingIdx < textLC.length &&
                !wordDelimiters.contains(textLC[
                    followingIdx])) // is character following the search term a delimiter?
            {
              // print('disqualify following: idx=$idx i=$i');
              continue; // following character isn't delimiter so disqualify
            }
          }

          // print('term #$i found at=$at (${termListLC[i]})');
          if (at < idxNearest) {
            // print('PEG');
            iNearest = i;
            idxNearest = at;
          }
        }
      }

      if (iNearest >= 0) {
        // found one of the terms at or after idx
        // iNearest is the index of the closest term at or after idx that matches

        // print('iNearest=$iNearest @ $idxNearest');
        if (start < idxNearest) {
          // we found a match BUT FIRST output non-highlighted text that comes BEFORE this match
          nonHighlightAdd(idxNearest);
          start = idxNearest;
        }

        // output the match using desired highlighting
        int termLen = termListLC[iNearest].length;
        children.add(TextSpan(
            text: text.substring(start, idxNearest + termLen),
            style: textStyleHighlight));
        start = idx = idxNearest + termLen;
      } else {
        if (words) {
          idx++;
          nonHighlightAdd(idx);
          start = idx;
        } else {
          // if none match at all (ever!)
          // --or--
          // one or more matches but during this iteration there are NO MORE matches
          // in either case, add reminder of text as non-highlighted text
          nonHighlightAdd(textLC.length);
          break;
        }
      }
    }

    return RichText(
        maxLines: maxLines,
        overflow: overflow,
        text: TextSpan(children: children, style: textStyle),
        textAlign: textAlign,
        textScaleFactor: MediaQuery.of(context).textScaleFactor);
  }

  List<InlineSpan> getTextStyle(String text) {
    List<InlineSpan> child = [];

    var pattern = RegExp(
        textStylePattern.keys.map((key) {
          return key;
        }).join('|'),
        multiLine: true);

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        for (var char in match[0].toString().characters) {
          if (char == '*') {
            isBold = !isBold;
            child.add(TextSpan(
                text: "",
                style: TextStyle(
                    fontSize: regexEmoji.allMatches(char).isNotEmpty ? 18 : 14,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    color: Colors.black,
                    fontFamily: Platform.isIOS
                        ? regexEmoji.allMatches(char).isNotEmpty
                            ? 'Apple Color Emoji'
                            : ''
                        : '')));
          } else if (char == '_') {
            isItalic = !isItalic;
            child.add(TextSpan(
                text: "",
                style: TextStyle(
                    fontSize: regexEmoji.allMatches(char).isNotEmpty ? 18 : 14,
                    color: Colors.black,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    fontFamily: Platform.isIOS
                        ? regexEmoji.allMatches(char).isNotEmpty
                            ? 'Apple Color Emoji'
                            : ''
                        : '')));
          } else {
            child.add(TextSpan(
                text: char,
                style: TextStyle(
                    fontSize: regexEmoji.allMatches(char).isNotEmpty ? 18 : 14,
                    color: Colors.black,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    fontFamily: Platform.isIOS
                        ? regexEmoji.allMatches(char).isNotEmpty
                            ? 'Apple Color Emoji'
                            : ''
                        : '')));
          }
        }

        return "";
      },
      onNonMatch: (String text) {
        for (String t in text.characters) {
          child.add(TextSpan(
              text: (term ?? '').isEmpty
                  ? t
                  : RegExp(r'[*_]+').allMatches(t).isNotEmpty
                      ? " "
                      : t,
              style: TextStyle(
                  fontSize: regexEmoji.allMatches(t).isNotEmpty ? 18 : 14,
                  color: Colors.black,
                  fontFamily: Platform.isIOS
                      ? regexEmoji.allMatches(t).isNotEmpty
                          ? 'Apple Color Emoji'
                          : ''
                      : '')));
        }
        return "";
      },
    );

    return child;
  }
}
