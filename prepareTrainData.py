from os.path import dirname, join as pjoin
import scipy.io as sio
import turicreate as tc
import pathlib
import numpy as np

def getCoordinates(frame):
    xMin = frame[:, 0].min()
    yMin = frame[:, 1].min()
    xMax = frame[:, 0].max()
    yMax = frame[:, 1].max()

    xCenter = (xMin + xMax) / 2
    yCenter = (yMin + yMax) / 2
    width = abs(xMax - xMin)
    height = abs(yMax - yMin)

    return {'height': height, 'width': width, 'x': xCenter, 'y': yCenter}

def getAnnotation(frameIndex, videoElement):

    videoId = videoElement['video_id']
    partnerVideoId = videoElement['partner_video_id']
    egoViewerId = videoElement['ego_viewer_id']
    partnerId = videoElement['partner_id']
    locationId = videoElement['location_id']
    activityId = videoElement['activity_id']

    labeledFrames = videoElement['labelled_frames']

    frame = labeledFrames[0][frameIndex]

    frameNum = frame['frame_num']

    annotationsForFrame = []
    global handLabels

    for label in handLabels:
        if label and len(frame[label]) > 0:
            coordinates = getCoordinates(frame[label])
            annotaionLabel = 'left' if label == 'myleft' or label == 'yourleft' else 'right' 
            entry = { 'coordinates' : coordinates, 'label' : annotaionLabel }
            annotationsForFrame.append(entry)
    key1 = videoId[0]
    key2 = frameNum[0][0]
    frameKey = '{0}/frame_{1:04d}.jpg'.format(key1, key2)

    return (frameKey, annotationsForFrame)

def createSFrame(imagesDir, videoIndices, framesPerVideoElement):
    metadata_mat_fname = pjoin(dirname(__file__), 'metadata.mat')
    videoStruct = sio.loadmat(metadata_mat_fname)
    videoStruct = videoStruct['video']
    annotationMap = {}
    for videoElementIndex in videoIndices:
        videoElement = videoStruct[0][videoElementIndex]
        for frameIndex in range(framesPerVideoElement):
            (key, value) = getAnnotation(frameIndex, videoElement)
            annotationMap[key] = value

    sf_images = tc.image_analysis.load_images(imagesDir, random_order=False, with_path=True)

    annotations = []
    global handLabels
    for index, imagePath in enumerate(sf_images['path']):
        keyParts = pathlib.Path(imagePath).parts[-2:]
        key = '{0}/{1}'.format(keyParts[0], keyParts[1])
        annotations.append(annotationMap[key] if key in annotationMap else None)
    
    annotationsFlatten = np.concatenate(annotations)
    lefthand = list(filter(lambda a: a is not None and a['label'] == 'left', annotationsFlatten))
    righthand = list(filter(lambda a: a is not None and a['label'] == 'right', annotationsFlatten))
    
    print('lefthand: {0} righthand: {1}'.format(len(lefthand), len(righthand)))

    sf_images['annotations'] = annotations
    sf_images = sf_images.dropna()
    sf_images['image_with_ground_truth'] = \
        tc.object_detector.util.draw_bounding_boxes(sf_images['image'], sf_images['annotations'])

    return sf_images

handLabels = ['myleft', 'myright', 'yourleft', 'yourright']
lastIndex = 48
fullRangeIndices = set(range(lastIndex))
framesPerVideoElement = 100
baseImagesDir = pjoin(dirname(__file__), '_LABELLED_SAMPLES')
sf = createSFrame(baseImagesDir, fullRangeIndices, framesPerVideoElement)
sf_train, sf_test = sf.random_split(.9, seed=5)
sf_train.save('train.sframe')
sf_test.save('test.sframe')