#!/bin/bash
# Tạo cấu trúc thư mục media cho cả 3 "ổ" và set quyền thoải mái

for BASE_DIR in /home/cuong/Data/Torrents /mnt/external /mnt/external2; do
    echo ">>> Tạo cấu trúc tại: $BASE_DIR/Media"

    mkdir -p "$BASE_DIR/Live_Action/Movies"
    mkdir -p "$BASE_DIR/Live_Action/TV_Shows"

    mkdir -p "$BASE_DIR/Anime/Movies"
    mkdir -p "$BASE_DIR/Anime/TV_Shows"

    mkdir -p "$BASE_DIR/Animated/Movies"
    mkdir -p "$BASE_DIR/Animated/TV_Shows"

    chown -R 1000:1000 "$BASE_DIR"
    chmod -R 777 "$BASE_DIR"
done

echo ">>> Hoàn tất!"
