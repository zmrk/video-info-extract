#!/bin/bash

# /videos/info 폴더가 없으면 생성
mkdir -p /videos/info

# /videos 폴더 내의 이벤트를 지속적으로 모니터링
inotifywait -m -e close_write -e moved_to -e delete -e moved_from --format '%w %e %f' /videos | while read -r dir event file; do
    # 만약 생성된 info 폴더 내의 이벤트라면 무시
    if [[ "$dir" == "/videos/info/" ]]; then
        continue
    fi

    filepath="${dir}${file}"

    # 파일 삭제 이벤트 처리
    if [[ "$event" == *"DELETE"* || "$event" == *"MOVED_FROM"* ]]; then
        echo "파일 삭제 감지: $filepath"
        # POST_URL이 설정되어 있다면 curl 호출
        if [ -n "$POST_URL" ]; then
            curl -X POST -H "Content-Type: application/json" \
                -d "{\"filename\": \"${file}\"}" \
                "$POST_URL"
        fi

    # 파일 생성/수정 이벤트 처리
    elif [[ "$event" == *"CLOSE_WRITE"* || "$event" == *"MOVED_TO"* ]]; then
        # mp4 파일만 처리
        if [[ "$file" =~ \.mp4$ ]]; then
            echo "영상 처리 시작: $filepath"
            base_name="${file%.*}"
            thumb_path="/videos/info/${base_name}.png"
            json_path="/videos/info/${base_name}.json"

            # 1초 지점에서 썸네일 생성 (파일명.png)
            ffmpeg -i "$filepath" -ss 00:00:01.000 -vframes 1 "$thumb_path" -y

            # 영상 길이 추출 (초 단위)
            duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filepath")
            echo "{\"duration\": $duration}" > "$json_path"
            echo "영상 길이: $duration 초 (저장파일: $json_path)"

            # POST_URL이 설정되어 있다면 영상 처리 결과를 POST 전송
            if [ -n "$POST_URL" ]; then
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"filename\": \"${file}\", \"thumbnail\": \"${thumb_path}\", \"duration\": $duration}" \
                    "$POST_URL"
            fi
        fi
    fi
done