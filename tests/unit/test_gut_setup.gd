extends GutTest

func test_gut_is_working():
	assert_true(true, "GUT framework is properly set up!")
	
func test_gut_assertions():
	assert_eq(1, 1)
	assert_ne(1, 2)
	assert_true(true)
	assert_false(false)