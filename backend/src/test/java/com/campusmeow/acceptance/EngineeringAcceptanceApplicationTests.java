package com.campusmeow.acceptance;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.SpringBootApplication;

class EngineeringAcceptanceApplicationTests {

	@Test
	void applicationUsesSpringBootConfiguration() {
		assertTrue(EngineeringAcceptanceApplication.class.isAnnotationPresent(SpringBootApplication.class));
	}

}
