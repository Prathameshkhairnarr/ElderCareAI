from PIL import Image

def crop_and_resize(input_path, output_path):
    img = Image.open(input_path)
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get bounding box of non-transparent areas
    bbox = img.getbbox()
    if bbox:
        # Crop to the bounding box
        img = img.crop(bbox)
        
        # Calculate new size with a bit of padding (e.g. 5% on each side)
        width, height = img.size
        # Make the canvas square
        max_size = max(width, height)
        # Add 5% padding so it's not cutting off the edges in adaptive icon circle
        padding = int(max_size * 0.1)
        new_size = max_size + 2 * padding
        
        # Create a new square image with transparent background
        new_img = Image.new('RGBA', (new_size, new_size), (0, 0, 0, 0))
        
        # Paste the cropped image in the center
        paste_x = (new_size - width) // 2
        paste_y = (new_size - height) // 2
        new_img.paste(img, (paste_x, paste_y))
        
        # Save
        new_img.save(output_path)
        print("Cropped and rescaled successfully!")
    else:
        print("Image is entirely transparent!")

if __name__ == '__main__':
    crop_and_resize('assets/images/logo.png', 'assets/images/logo.png')
