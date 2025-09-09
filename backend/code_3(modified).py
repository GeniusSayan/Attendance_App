import cv2
import os
import numpy as np
import faiss
from insightface.app import FaceAnalysis

# --- Config ---
DATASET_PATH = "data"
EMBEDDINGS_FILE = "embeddings.npz"
CONFIDENCE_THRESHOLD = 0.7

# --- Initialize Face Detector ---
face_detector = FaceAnalysis(name="buffalo_l")
face_detector.prepare(ctx_id=0)  # Use GPU (0) or CPU (-1) # Not Working...

# --- Initialize FAISS ---
embedding_size = 512
faiss_index = faiss.IndexFlatIP(embedding_size)
embeddings_db = {}


# --- Load Saved Embeddings ---
def load_embeddings():
    """Loads embeddings from a file and updates FAISS."""
    global embeddings_db, faiss_index
    if os.path.exists(EMBEDDINGS_FILE):
        data = np.load(EMBEDDINGS_FILE, allow_pickle=True)
        embeddings_db = {name: data[name] for name in data.files}
        
        faiss_index.reset()
        if embeddings_db:
            embeddings_list = np.array([normalize_embedding(e) for e in embeddings_db.values()])
            faiss_index.add(embeddings_list)

        print(f"Loaded {len(embeddings_db)} students from embeddings.")


# --- Save Embeddings ---
def save_embeddings():
    """Saves embeddings to a file and updates FAISS."""
    global faiss_index
    np.savez(EMBEDDINGS_FILE, **embeddings_db)

    faiss_index.reset()
    embeddings_list = [normalize_embedding(e) for e in embeddings_db.values()]
    
    if embeddings_list:
        faiss_index.add(np.array(embeddings_list))


# --- Normalize Embedding ---
def normalize_embedding(embedding):
    """Normalizes an embedding vector to unit length."""
    return embedding / np.linalg.norm(embedding)


# --- Extract Face Embeddings ---
def get_face_embedding(image, multiple=False):
    """Extracts face embeddings from an image."""
    faces = face_detector.get(image)
    if not faces:
        return None, None

    embeddings = [face.normed_embedding for face in faces]
    bboxes = [face.bbox for face in faces]

    return (embeddings, bboxes) if multiple else (embeddings[0], bboxes[0])


# --- Recognize Faces ---
def recognize_faces(image_path, threshold=0.7):
    """Recognizes multiple faces efficiently from an image and saves the result."""
    unknown = 0
    recognized = 0
    image = cv2.imread(image_path)
    if image is None:
        print("❌ Error: Could not load image.")
        return
    original_height, original_width = image.shape[:2]

    # --- Resize if too large ---
    max_display_size = 800  # Max width/height for display
    scale = min(max_display_size / original_width, max_display_size / original_height, 1.0)

    new_width = int(original_width * scale)
    new_height = int(original_height * scale)
    resized_image = cv2.resize(image, (new_width, new_height)) if scale < 1 else image

    #Detect all faces at once
    embeddings, bboxes = get_face_embedding(image, multiple=True)

    if not embeddings:
        print("⚠️ No face detected.")
        return

    # Normalize all embeddings before searching
    embeddings = np.array([normalize_embedding(e) for e in embeddings])

    #Batch search in FAISS (instead of looping)
    D, I = faiss_index.search(embeddings, 2)  # Reduce `k=5` → `k=2` for speed

    for i, (embedding, bbox) in enumerate(zip(embeddings, bboxes)):
        best_match_idx = I[i][0]
        best_match_score = D[i][0]

        # best_match_embedding = list(embeddings_db.values())[best_match_idx]
        # cosine_similarity = np.dot(embedding, best_match_embedding.T).item()
        confidence = (best_match_score + 1) / 2  # Normalize to 0-1

        #Fix Unknown Detection
        if confidence < threshold:
            name = "Unknown"
            color = (0, 0, 255) # Red for unknown
            unknown += 1
        else:
            name = list(embeddings_db.keys())[best_match_idx]
            color = (0, 255, 0)  # Green for known faces
            recognized += 1

        print(f"Best Match: {name} (Confidence: {confidence:.2f})")

        # --- Draw Bounding Box ---
        x1, y1, x2, y2 = map(int, bbox)
        if scale < 1:  # Adjust bounding box if resized
            x1, y1, x2, y2 = [int(coord * scale) for coord in [x1, y1, x2, y2]]

        cv2.rectangle(resized_image, (x1, y1), (x2, y2), color, 2)
        label = f"{name} ({confidence:.2f})"
        cv2.putText(resized_image, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color , 2)

    # --- Save & Show Output ---
    print("Recognized: " ,recognized)
    print("Unknown: " , unknown)
    filename = os.path.basename(image_path)
    name_part, ext = os.path.splitext(filename)
    output_path = os.path.join("result", f"{name_part}_output{ext}")
    cv2.imwrite(output_path, resized_image)

    cv2.imshow("Face Recognition", resized_image)
    cv2.waitKey(0)
    cv2.destroyAllWindows()


# ---Live recognition---
def recognize_faces_live():
    """Detects and recognizes multiple faces live from the webcam efficiently."""
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("❌ Error: Could not open webcam.")
        return

    print("Live face recognition started. Press 'q' to exit.")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("❌ Failed to capture frame.")
            break

        # Detect all faces at once
        embeddings, bboxes = get_face_embedding(frame, multiple=True)

        if embeddings:
            embeddings = np.array([normalize_embedding(e) for e in embeddings])  # Normalize all embeddings

            # Batch search instead of looping over each face
            D, I = faiss_index.search(embeddings, 3)  # Reduce k from 5 to 3 for speed

            for i, (embedding, bbox) in enumerate(zip(embeddings, bboxes)):
                best_match_idx = I[i][0]
                best_match_score = D[i][0]

                best_match_embedding = list(embeddings_db.values())[best_match_idx]
                cosine_similarity = np.dot(embedding, best_match_embedding.T).item()
                confidence = (cosine_similarity + 1) / 2  # Normalize similarity

                if confidence < CONFIDENCE_THRESHOLD:
                    name = "Unknown"
                    color = (0, 0, 255)  # Red for unknown
                else:
                    name = list(embeddings_db.keys())[best_match_idx]
                    color = (0, 255, 0)  # Green for known faces

                x1, y1, x2, y2 = map(int, bbox)
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, f"{name} ({confidence:.2f})", (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        cv2.imshow("Live Face Recognition", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("Live recognition stopped.")


# --- Capture & Add a New Student ---
def add_new_student(name, num_images):
    """Captures images from webcam and adds a new student."""
    cap = cv2.VideoCapture(0)
    student_folder = os.path.join(DATASET_PATH, name)
    os.makedirs(student_folder, exist_ok=True)

    for i in range(num_images):
        ret, frame = cap.read()
        if not ret:
            print("❌ Failed to capture image.")
            continue

        image_path = os.path.join(student_folder, f"{name}_{i+1}.jpg")
        cv2.imwrite(image_path, frame)
        print(f"Saved: {image_path}")

    cap.release()
    scan_dataset()


# --- Scan Dataset for New Students ---
def scan_dataset():
    """Scans the dataset and updates embeddings for new students."""
    global embeddings_db
    print("🔄 Scanning dataset...")
    
    skipped = 0
    for student_name in os.listdir(DATASET_PATH):
        student_path = os.path.join(DATASET_PATH, student_name)
        if not os.path.isdir(student_path):
            continue

        if student_name in embeddings_db:
            continue  # Skip already added students

        print(f"🔄 Processing student: {student_name}")

        embeddings_list = []
        for filename in os.listdir(student_path):
            if filename.lower().endswith(('.jpg', '.jpeg')):  # Fix for JPEG images
                image_path = os.path.join(student_path, filename)
                image = cv2.imread(image_path)
                
                if image is None:
                    print(f"⚠️ Skipping {filename} (Corrupt or unreadable)")
                    skipped += 1
                    continue

                embeddings, bboxes = get_face_embedding(image, multiple=True)
                if embeddings:
                    # Select the largest face
                    largest_face_idx = np.argmax([(x2 - x1) * (y2 - y1) for (x1, y1, x2, y2) in bboxes])
                    embedding = embeddings[largest_face_idx]

                    embeddings_list.append(embedding)
                    print(f"   ✅ Added {filename} to FAISS")
                else:
                    print(f"❌ Skipped (No face detected): {filename}")

        if embeddings_list:
            avg_embedding = normalize_embedding(np.mean(embeddings_list, axis=0))
            embeddings_db[student_name] = avg_embedding
            print(f"✅ Added {student_name} to database.")

    save_embeddings()
    print(f" Finished scanning. {len(embeddings_db)} students stored.")
    if skipped > 0:
        print(f"⚠️ {skipped} images were skipped due to errors.")


# --- View All Students ---
def view_students():
    """Displays all registered students."""
    print("Registered Students:")
    for student in embeddings_db.keys():
        print(f"- {student}")


# --- Main Menu (Switch Case) ---
def main():
    load_embeddings()

    while True:
        print("\n-----Face Recognition System-----")
        print("1. Recognize Faces from an Image")
        print("2. Add a New Student (Capture from Camera)")
        print("3. Scan Dataset for New Students")
        print("4. View All Registered Students")
        print("5. Live Face Recognition from Camera")
        print("6. Exit")
        choice = input("->Enter your choice: ")

        if choice == "1":
            image_path = input("Enter image path: ")
            recognize_faces(image_path)

        elif choice == "2":
            name = input("Enter student name: ")
            num_images = int(input("How many images to capture? "))
            add_new_student(name, num_images)

        elif choice == "3":
            scan_dataset()

        elif choice == "4":
            view_students()

        elif choice == "5":
            recognize_faces_live()

        elif choice == "6":
            print("Exiting...")
            break
        
        else:
            print("Invalid choice. Try again!")


# --- Run the program ---
if __name__ == "__main__":
    main()