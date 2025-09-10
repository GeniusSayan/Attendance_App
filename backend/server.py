import base64
import os
from flask import Flask, jsonify , request
from flask_cors import CORS
import numpy as np
import cv2
from face_recognition_code import face_recognition

app = Flask(__name__)
CORS(app)
obj = face_recognition()
dataset = r"C:\Users\user\Desktop\face_recognizer_backend_server\dataset"

@app.route('/' , methods=['POST' , 'GET'])
def home():
    return "Server Running"

@app.route('/add_person', methods=['POST'])
def add_person():
    name = request.form.get("name")
    if not name:
        return {'status': 'name not found'} , 400
    
    name = name.strip()
    name = name.lower()
    person_dir = os.path.join(dataset , name)

    if not os.path.exists(person_dir):
        os.makedirs(person_dir)

    file = request.files['image']
    if not file:
        return {'status':'image not found'} , 400
    
    npimg = np.frombuffer(file.read(), np.uint8)
    frame = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    if frame is not None:
        image_path = os.path.join(person_dir , f"{name}_{len(os.listdir(person_dir)) + 1}.jpg")
        cv2.imwrite(image_path , frame)
        obj.embeddings_db = {}
        obj.load_embeddings()
        obj.scan_dataset()
        obj.load_embeddings()
        obj.view_students()
        return {'status':'image saved successfully'} , 200
   
    return {'status':"image decoding failed"}, 500

#---not using rn---
@app.route('/face_recognition', methods=['POST'])
def receive_image():
    file = request.files['image']
    npimg = np.frombuffer(file.read(), np.uint8)
    frame = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
    data = []
    if frame is not None:
        data , image = obj.recognize_faces(frame)

        # Convert processed image to Base64
        _, buffer = cv2.imencode('.jpg', image)
        base64_image = base64.b64encode(buffer).decode("utf-8")

        print(obj.recognize_faces_start_time)
        print(obj.get_face_embedding_start_time)
        print(obj.normalize_embedding_start_time)
        print(obj.recognize_faces_end_time)
        print("Recognized Nos: " , obj.recognized_face_count)
        print("unknown face count: " , obj.unknown_face_count)
        return {"data":data , 
                "times":[obj.recognize_faces_start_time , obj.get_face_embedding_start_time , obj.normalize_embedding_start_time , obj.recognize_faces_end_time] , 
                "face_counts":[f"{obj.recognized_face_count}" , f"{obj.unknown_face_count}"],
                "processed_image": base64_image,}, 200
   
    return "Not", 500


@app.route('/view_students' , methods = ['POST'])
def student_names():
    data = request.get_json()
    section = data.get('section')
    obj.EMBEDDINGS_FILE = f"{section}.npz"
    obj.embeddings_db = {}
    obj.load_embeddings()
    data = obj.view_students()
    return data ,200

@app.route('/recognize_face' , methods= ["POST"])
def recognize_images():
    frames = []
    data = []
    base64_image = []
    recognized_names = []

    files = request.files.getlist('image')
    section = request.form.get("section")
    
    for file in files:
        npimg = np.frombuffer(file.read(), np.uint8)
        frames.append(cv2.imdecode(npimg, cv2.IMREAD_COLOR))

    if frames is not None:
        obj.EMBEDDINGS_FILE = f"{section}.npz"
        obj.embeddings_db = {}
        obj.load_embeddings()
        obj.view_students()
        print(section)

        for frame in frames:
            data , image = obj.recognize_faces(frame)

            for entry in data:
                recognized_names.append(entry["name"])

            _, buffer = cv2.imencode('.jpg', image)
            base64_image.append(base64.b64encode(buffer).decode("utf-8"))

        print(set(recognized_names))
        recognized_names = set(recognized_names)
        recognized_names = list(recognized_names)

        return {"data": recognized_names,
                "processed_images": base64_image} , 200
    
    return "Not" , 500
        


if __name__ == '__main__':
    # obj.load_embeddings()
    # obj.view_students()
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)


# conn = get_db_connection()
# cursor = conn.cursor(dictionary=True)
# cursor.execute("insert into Students values(2,'Navonil' , '25' , 6 , 1 , 'A' , 'navonilganguli@gmail.com' , 'navonil');")
# data = cursor.fetchall()

# for i in range(len(data)):
#     d = data[i]
#     print(d)

# conn.commit()
# conn.close()