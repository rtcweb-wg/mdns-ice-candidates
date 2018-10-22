TARGETS_DRAFTS := draft-ietf-rtcweb-mdns-ice-candidates
TARGETS_TAGS := 
draft-ietf-rtcweb-mdns-ice-candidates-00.md: draft-ietf-rtcweb-mdns-ice-candidates.md
	sed -e 's/draft-ietf-rtcweb-mdns-ice-candidates-latest/draft-ietf-rtcweb-mdns-ice-candidates-00/g' -e 's/draft-ietf-rtcweb-mdns-ice-candidates-latest/draft-ietf-rtcweb-mdns-ice-candidates-00/g' $< >$@
