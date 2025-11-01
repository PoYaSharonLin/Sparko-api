import sys
import json
import os
from sentence_transformers import SentenceTransformer
import numpy as np


# A custom JSON encoder to handle numpy arrays
class NumpyEncoder(json.JSONEncoder):
    """ Special json encoder for numpy types """
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        if isinstance(obj, np.floating):
            return float(obj)
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        return json.JSONEncoder.default(self, obj)


def main():
    """
    Reads text from stdin, generates a sentence embedding,
    and prints it to stdout as a JSON array.
    """
    try:
        cache_dir = os.environ.get('TRANSFORMERS_CACHE')
        model = SentenceTransformer('all-MiniLM-L6-v2', cache_folder=cache_dir)
        input_text = sys.stdin.read().strip()

        if not input_text:
            print(json.dumps([]))
            return

        embedding = model.encode(input_text)
        json_output = json.dumps(embedding, cls=NumpyEncoder)
        print(json_output)

    except Exception as error:
        print(f"Error in embedder.py: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
