#!/bin/bash

# /videos/info 폴더가 없으면 생성
mkdir -p /videos/info

# /videos 폴더의 이벤트를 지속적으로 모니터링
inotifywait -m -e close_write -e moved_to -e delete -e moved_from --format '%w %e %f' /videos | while read -r dir event file; do
    # /videos/info 폴더 내의 이벤트는 무시
    if [[ "$dir" == "/videos/info/" ]]; then
        continue
    fi

    filepath="${dir}${file}"

    # 파일 삭제 이벤트 처리
    if [[ "$event" == *"DELETE"* || "$event" == *"MOVED_FROM"* ]]; then
        echo "파일 삭제 감지: $filepath"
        if [ -n "$API_URL" ]; then
            curl -X DELETE -H "Content-Type: application/json" \
                -d "{\"filename\": \"${file}\"}" \
                "$API_URL"
        fi

    # 파일 생성/수정 이벤트 처리
    elif [[ "$event" == *"CLOSE_WRITE"* || "$event" == *"MOVED_TO"* ]]; then
        # mp4 파일만 처리
        if [[ "$file" =~ \.mp4$ ]]; then
            echo "영상 처리 시작: $filepath"
            base_name="${file%.*}"
            timestamp=$(date +%s)
            thumb_path="/videos/info/${base_name}_${timestamp}.png"
            json_path="/videos/info/${base_name}_${timestamp}.json"

            # 1초 지점에서 썸네일 생성 (에러 발생 시 에러 메시지를 JSON에 저장)
            ffmpeg_output=$(ffmpeg -i "$filepath" -ss 00:00:01.000 -vframes 1 "$thumb_path" -y 2>&1)
            if [ $? -ne 0 ]; then
                error_message=$(echo "$ffmpeg_output" | sed 's/"/\\"/g')
                echo "{\"error\": \"$error_message\"}" > "$json_path"
                echo "썸네일 생성 중 에러 발생: $error_message"
                continue
            fi

            # 영상 길이 추출 (ffprobe 에러 발생 시 에러 메시지를 JSON에 저장)
            duration_output=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filepath" 2>&1)
            if [ $? -ne 0 ]; then
                error_message=$(echo "$duration_output" | sed 's/"/\\"/g')
                echo "{\"error\": \"$error_message\"}" > "$json_path"
                echo "영상 길이 추출 중 에러 발생: $error_message"
                continue
            fi

            # 추출된 영상 길이 값 정리 (개행 문자 제거)
            duration=$(echo "$duration_output" | tr -d '\n')
            echo "{\"duration\": $duration}" > "$json_path"
            echo "영상 길이: $duration 초 (저장파일: $json_path)"

            # API_URL이 설정되어 있다면 영상 처리 결과를 POST 전송
            if [ -n "$API_URL" ]; then
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"filename\": \"${file}\", \"thumbnail\": \"${thumb_path}\", \"duration\": $duration}" \
                    "$API_URL"
            fi
        fi
    fi
done