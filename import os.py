import os
import xml.etree.ElementTree as ET
from PIL import Image
import shutil
import random
from collections import defaultdict

# === CONFIG ===
# Use raw string or forward slashes to fix the Windows path error
dataset_dir = r"C:\Users\omara\OneDrive\Documents\Desktop\school\me\freelance\salah posture\Salat-All-img-xml"
output_base = 'classified_dataset'  # Final output folder
train_split = 0.8
val_split = 0.1
test_split = 0.1

# === LABEL NORMALIZATION ===
label_map = {
    'Sujud': 'sujud',
    'sujud': 'sujud',
    'julus': 'sitting',
    'sitting': 'sitting',
    'qiyam': 'qiyam',
    'ruku': 'ruku'
}

# === CREATE FOLDER STRUCTURE ===
splits = ['train', 'val', 'test']
class_labels = set(label_map.values())

for split in splits:
    for label in class_labels:
        os.makedirs(os.path.join(output_base, split, label), exist_ok=True)

# === COLLECT CROPPED IMAGES ===
cropped_images = defaultdict(list)

for file in os.listdir(dataset_dir):
    if not file.endswith('.xml'):
        continue

    xml_path = os.path.join(dataset_dir, file)
    image_base = os.path.splitext(file)[0]
    possible_exts = ['.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG']

    image_path = None
    for ext in possible_exts:
        temp_path = os.path.join(dataset_dir, image_base + ext)
        if os.path.exists(temp_path):
            image_path = temp_path
            break

    if image_path is None:
        print(f"❌ Missing image for {file}")
        continue

    try:
        image = Image.open(image_path).convert('RGB')
    except:
        print(f"⚠️ Failed to open {image_path}")
        continue

    tree = ET.parse(xml_path)
    root = tree.getroot()

    for idx, obj in enumerate(root.findall('object')):
        raw_label = obj.find('name').text.strip()
        label = label_map.get(raw_label)

        if label is None:
            print(f"⚠️ Unknown label: {raw_label} in {file}")
            continue

        bndbox = obj.find('bndbox')
        if bndbox is None:
            print(f"⚠️ Missing <bndbox> in {file}")
            continue

        try:
            xmin = int(float(bndbox.find('xmin').text))
            ymin = int(float(bndbox.find('ymin').text))
            xmax = int(float(bndbox.find('xmax').text))
            ymax = int(float(bndbox.find('ymax').text))
        except Exception as e:
            print(f"⚠️ Incomplete bounding box in {file}: {e}")
            continue


        cropped = image.crop((xmin, ymin, xmax, ymax))
        new_name = f"{image_base}_{idx}.jpg"
        cropped_images[label].append((cropped, new_name))

# === SPLIT AND SAVE ===
for label, items in cropped_images.items():
    random.shuffle(items)
    total = len(items)
    train_end = int(total * train_split)
    val_end = train_end + int(total * val_split)

    data_splits = {
        'train': items[:train_end],
        'val': items[train_end:val_end],
        'test': items[val_end:]
    }

    for split, entries in data_splits.items():
        for img, name in entries:
            save_path = os.path.join(output_base, split, label, name)
            img.save(save_path)

print("✅ Dataset organized into classified_dataset/train/val/test folders by posture.")
