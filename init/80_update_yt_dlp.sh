#!/bin/bash

logger -s -t $0 "Updating yt-dlp..."
/usr/local/bin/yt-dlp -U || logger -s -t $0 "yt-dlp update failed; keeping existing version"
