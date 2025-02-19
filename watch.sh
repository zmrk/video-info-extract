#!/bin/bash

# /info 폴더가 없으면 생성
mkdir -p /info

# /videos 폴더의 이벤트를 지속적으로 모니터링
inotifywait -m -e close_write -e moved_to -e delete -e moved_from --format '%w %e %f' /videos | while read -r dir event file; do
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
            thumb_path="/info/${base_name}_${timestamp}.png"
            json_path="/info/${base_name}_${timestamp}.json"

            # 1초 지점에서 썸네일 생성
            ffmpeg_output=$(ffmpeg -i "$filepath" -ss 00:00:01.000 -vframes 1 "$thumb_path" -y 2>&1)
            if [ $? -ne 0 ]; then
                error_message=$(echo "$ffmpeg_output" | sed 's/"/\\"/g')
                echo "{\"error\": \"$error_message\"}" > "$json_path"
                echo "썸네일 생성 중 에러 발생: $error_message"
                # 에러 발생시에도 API 호출 (filename과 json 경로 전달)
                if [ -n "$API_URL" ]; then
                    curl -X POST -H "Content-Type: application/json" \
                        -d "{\"filename\": \"${file}\", \"json_path\": \"${json_path}\"}" \
                        "$API_URL"
                fi
                continue
            fi

            # 영상 길이 추출
            duration_output=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$filepath" 2>&1)
            if [ $? -ne 0 ]; then
                error_message=$(echo "$duration_output" | sed 's/"/\\"/g')
                echo "{\"error\": \"$error_message\"}" > "$json_path"
                echo "영상 길이 추출 중 에러 발생: $error_message"
                # 에러 발생시에도 API 호출 (filename과 json 경로 전달)
                if [ -n "$API_URL" ]; then
                    curl -X POST -H "Content-Type: application/json" \
                        -d "{\"filename\": \"${file}\", \"json_path\": \"${json_path}\"}" \
                        "$API_URL"
                fi
                continue
            fi

            # 개행 문자 제거 후 영상 길이 저장
            duration=$(echo "$duration_output" | tr -d '\n')
            echo "{\"duration\": $duration}" > "$json_path"
            echo "영상 길이: $duration 초 (저장파일: $json_path)"

            # 영상 처리 완료 후 API 호출 (POST 메서드 사용)
            if [ -n "$API_URL" ]; then
                curl -X POST -H "Content-Type: application/json" \
                    -d "{\"filename\": \"${file}\", \"thumbnail\": \"${thumb_path}\", \"duration\": $duration}" \
                    "$API_URL"
            fi
        fi
    fi
done