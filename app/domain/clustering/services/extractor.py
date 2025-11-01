import sys
import json
from string import punctuation
from collections import Counter

# NLTK Stopwords lists
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
    # extract concept using 1 word instead of n-gram
    text = ''.join(c for c in text if c not in punctuation)
    text = text.lower()
    words = text.split()
    words = [word for word in words if word not in stop_words and len(word) > 1]  # Ignore single-letter words
    word_counts = Counter(words)
    return [word for word, count in word_counts.most_common(top_n)]


if __name__ == "__main__":
    # reading summary object from Ruby
    summary = sys.stdin.read().strip()
    concepts = extract_concepts(summary)
    # output json
    print(json.dumps(concepts))
