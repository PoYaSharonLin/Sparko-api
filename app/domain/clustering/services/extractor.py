import sys
import json
from string import punctuation
from collections import Counter
from itertools import chain

# NLTK Stopwords lists (kept the same)
stop_words = [
    'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you', "you're", "you've", "you'll", "you'd",
    'your', 'yours', 'yourself', 'yourselves', 'he', 'him', 'his', 'himself', 'she', "she's", 'her', 'hers',
    'herself', 'it', "it's", 'its', 'itself', 'they', 'them', 'their', 'theirs', 'themselves', 'what', 'which',
    'who', 'whom', 'this', 'that', "that'll", 'these', 'those', 'am', 'is', 'are', 'was', 'were', 'be', 'been',
    'being', 'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing', 'a', 'an', 'the', 'and', 'but', 'if',
    'or', 'because', 'as', 'until', 'while', 'of', 'at', 'by', 'for', 'with', 'about', 'against', 'between',
    'into', 'through', 'during', 'before', 'after', 'above', 'below', 'to', 'from', 'up', 'down', 'in', 'out',
    'on', 'off', 'over', 'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why',
    'how', 'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not',
    'only', 'own', 'same', 'so', 'than', 'too', 'very', 's', 't', 'can', 'will', 'just', 'don', "don't", 'should',
    "should've", 'now', 'd', 'll', 'm', 'o', 're', 've', 'y', 'ain', 'aren', "aren't", 'could', "couldn't",
    'did', "didn't", 'does', "doesn't", 'had', "hadn't", 'has', "hasn't", 'have', "haven't", 'having', 'he',
    "he'd", "he'll", "he's", 'how', "how's", 'i', "i'd", "i'll", "i'm", "i've", 'it', "it's", 'its', 'let',
    "let's", 'ma', 'might', "mightn't", 'must', "mustn't", 'need', "needn't", 'shan', "shan't", 'should',
    "shouldn't", 'was', "wasn't", 'were', "weren't", 'what', "what's", 'when', "when's", 'where', "where's",
    'who', "who's", 'why', "why's", 'will', 'with', "won't", 'would', "wouldn't"
]


def extract_concepts(text, top_n=10):
    text = ''.join(c for c in text if c not in punctuation)
    text = text.lower()
    words = text.split()

    # generate unigram, bigram, and trigram
    unigrams = [word for word in words if word not in stop_words and len(word) > 1]
    bigrams = [' '.join(gram) for gram in zip(words, words[1:]) if not any(word in stop_words for word in gram)]
    trigrams = [' '.join(gram) for gram in zip(words, words[1:], words[2:]) if not any(word in stop_words for word in gram)]

    all_ngrams = list(chain(unigrams, bigrams, trigrams))
    ngram_counts = Counter(all_ngrams)
    most_common_ngrams = [gram for gram, count in ngram_counts.most_common(top_n * 3)]

    # exclude subgrams
    final_concepts = []
    for ngram in most_common_ngrams:
        is_subgram = False
        for other_ngram in most_common_ngrams:
            if ngram != other_ngram and ngram in other_ngram:
                is_subgram = True
                break
        if not is_subgram:
            final_concepts.append(ngram)

    return final_concepts[:top_n]


if __name__ == "__main__":
    summary = sys.stdin.read().strip()
    concepts = extract_concepts(summary)
    print(json.dumps(concepts))