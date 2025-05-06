#include "video.hpp"


#define BIND_METHOD(method_name) \
    ClassDB::bind_method(D_METHOD(#method_name), &Video::method_name)

void Video::_bind_methods() {
	BIND_METHOD(test);
}

