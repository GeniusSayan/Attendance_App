import datetime
import cv2
import os
import numpy as np
import faiss
from insightface.app import FaceAnalysis

class face_recognition():
    def __init__(self):
        # --- Config ---
        self.DATASET_PATH = r"C:\Users\user\Desktop\face_recognizer_backend_server\dataset"
        self.EMBEDDINGS_FILE = "embeddings.npz"
        self.CONFIDENCE_THRESHOLD = 0.7

        # --- Initialize Face Detector ---
        self.face_detector = FaceAnalysis(name="buffalo_l")
        self.face_detector.prepare(ctx_id=0)  # Use GPU (0) or CPU (-1)

        # --- Initialize FAISS ---
        self.embedding_size = 512  # Based on RetinaFace model output
        self.faiss_index = faiss.IndexFlatL2(self.embedding_size)
        self.embeddings_db = {}

        self.recognize_faces_start_time = str
        self.get_face_embedding_start_time = str
        self.normalize_embedding_start_time = str
        self.recognize_faces_end_time = str
        self.recognized_face_count = 0
        self.unknown_face_count = 0


    # --- Load Saved Embeddings ---
    def load_embeddings(self):
        """Loads embeddings from a file and updates FAISS."""
        if os.path.exists(self.EMBEDDINGS_FILE):
            data = np.load(self.EMBEDDINGS_FILE, allow_pickle=True)
            self.embeddings_db = {name: data[name] for name in data.files}
            
            self.faiss_index.reset()
            if self.embeddings_db:
                self.embeddings_list = np.array([self.normalize_embedding(e) for e in self.embeddings_db.values()])
                self.faiss_index.add(self.embeddings_list)

            print(f"✅ Loaded {len(self.embeddings_db)} students from embeddings.")


    # --- Save Embeddings ---
    def save_embeddings(self):
        """Saves embeddings to a file and updates FAISS."""
        np.savez(self.EMBEDDINGS_FILE, **self.embeddings_db)

        self.faiss_index.reset()
        embeddings_list = [self.normalize_embedding(e) for e in self.embeddings_db.values()]
        
        if embeddings_list:
            self.faiss_index.add(np.array(embeddings_list))


    # --- Normalize Embedding ---
    def normalize_embedding(self,embedding):
        """Normalizes an embedding vector to unit length."""
        return embedding / np.linalg.norm(embedding)


    # --- Extract Face Embeddings ---
    def get_face_embedding(self,image, multiple=False):
        """Extracts face embeddings from an image."""
        self.get_face_embedding_start_time = f"{datetime.datetime.now().hour}:{datetime.datetime.now().minute}:{datetime.datetime.now().second}"
        print("embedding start: " ,self.get_face_embedding_start_time)
        faces = self.face_detector.get(image)
        if not faces:
            return None, None

        embeddings = [face.normed_embedding for face in faces]
        bboxes = [face.bbox for face in faces]

        return (embeddings, bboxes) if multiple else (embeddings[0], bboxes[0])


    def recognize_faces(self , image, threshold=0.7):
        """Recognizes multiple faces efficiently from an image and saves the result."""
        data = []
        self.recognize_faces_start_time = f"{datetime.datetime.now().hour}:{datetime.datetime.now().minute}:{datetime.datetime.now().second}"
        print("recognize start: " ,self.recognize_faces_start_time)

        self.normalize_embedding_start_time = ""
        self.recognized_face_count = 0
        self.unknown_face_count = 0

        # 🔥 Detect all faces at once
        embeddings, bboxes = self.get_face_embedding(image, multiple=True)

        if not embeddings:
            print("⚠️ No face detected.")
            self.recognize_faces_end_time = f"{datetime.datetime.now().hour}:{datetime.datetime.now().minute}:{datetime.datetime.now().second}"
            return data , image

        # Normalize all embeddings before searching
        self.normalize_embedding_start_time = f"{datetime.datetime.now().hour}:{datetime.datetime.now().minute}:{datetime.datetime.now().second}"
        print("normalize start: ",self.normalize_embedding_start_time)
        embeddings = np.array([self.normalize_embedding(e) for e in embeddings])

        # 🔥 Batch search in FAISS (instead of looping)
        D, I = self.faiss_index.search(embeddings, 2)  # Reduce `k=5` → `k=2` for speed

        for i, (embedding, bbox) in enumerate(zip(embeddings, bboxes)):
            best_match_idx = I[i][0]
            best_match_score = D[i][0]

            best_match_embedding = list(self.embeddings_db.values())[best_match_idx]
            cosine_similarity = np.dot(embedding, best_match_embedding.T).item()
            confidence = (cosine_similarity + 1) / 2  # Normalize to 0-1

            # 🔥 Fix Unknown Detection
            if confidence < threshold:
                name = "Unknown" 
                color = (0, 0, 255) # Red for unknown
                self.unknown_face_count += 1
            else:
                name = list(self.embeddings_db.keys())[best_match_idx]  
                color = (0, 255, 0) # Green for known faces
                self.recognized_face_count += 1
                data.append({"name": f"{name}" , "confidence": f"{confidence*100:.2f}"})

            print(f"🆔 Best Match: {name} (Confidence: {confidence:.2f})")

            # --- Draw Bounding Box ---
            x1, y1, x2, y2 = map(int, bbox)

            cv2.rectangle(image, (x1, y1), (x2, y2), color, 10)
            label = f"{name} ({confidence:.2f})"
            cv2.putText(image, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        self.recognize_faces_end_time = f"{datetime.datetime.now().hour}:{datetime.datetime.now().minute}:{datetime.datetime.now().second}"
        print("recognize end: ",self.recognize_faces_end_time)
        return data , image


    # --- Scan Dataset for New Students ---
    def scan_dataset(self):
        """Scans the dataset and updates embeddings for new students."""
        print("🔄 Scanning dataset...")
        
        skipped = 0
        for student_name in os.listdir(self.DATASET_PATH):
            student_path = os.path.join(self.DATASET_PATH, student_name)
            if not os.path.isdir(student_path):
                continue

            if student_name in self.embeddings_db:
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

                    embeddings, bboxes = self.get_face_embedding(image, multiple=True)
                    if embeddings:
                        # Select the largest face
                        largest_face_idx = np.argmax([(x2 - x1) * (y2 - y1) for (x1, y1, x2, y2) in bboxes])
                        embedding = embeddings[largest_face_idx]

                        embeddings_list.append(embedding)
                        print(f"   ✅ Added {filename} to FAISS")
                    else:
                        print(f"❌ Skipped (No face detected): {filename}")

            if embeddings_list:
                avg_embedding = self.normalize_embedding(np.mean(embeddings_list, axis=0))
                self.embeddings_db[student_name] = avg_embedding
                print(f"✅ Added {student_name} to database.")

        self.save_embeddings()
        print(f"✅ Finished scanning. {len(self.embeddings_db)} students stored.")
        if skipped > 0:
            print(f"⚠️ {skipped} images were skipped due to errors.")


    # --- View All Students ---
    def view_students(self):
        data = []
        """Displays all registered students."""
        print("👥 Registered Students:")
        for student in self.embeddings_db.keys():
            data.append({'name': f"{student}"})
            print(f"- {student}")
        return data

    # --- Main Menu (Switch Case) ---
    # def main(self):
    #     self.load_embeddings()

    #     while True:
    #         print("\n🎭 Face Recognition System")
    #         print("1️⃣ Recognize Faces from an Image")
    #         print("2️⃣ Add a New Student (Capture from Camera)")
    #         print("3️⃣ Scan Dataset for New Students")
    #         print("4️⃣ View All Registered Students")
    #         print("5️⃣ Live Face Recognition from Camera")
    #         print("6️⃣ Exit")
    #         choice = input("➡️ Enter your choice: ")

    #         if choice == "1":
    #             image_path = input("📂 Enter image path: ")
    #             self.recognize_faces(image_path)

    #         elif choice == "2":
    #             name = input("🆕 Enter student name: ")
    #             num_images = int(input("📸 How many images to capture? "))
    #             self.add_new_student(name, num_images)

    #         elif choice == "3":
    #             self.scan_dataset()

    #         elif choice == "4":
    #             self.view_students()

    #         elif choice == "5":
    #             self.recognize_faces_live()

    #         elif choice == "6":
    #             print("👋 Exiting...")
    #             break
            
    #         else:
    #             print("❌ Invalid choice. Try again!")