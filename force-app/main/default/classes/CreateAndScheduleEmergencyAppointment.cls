public with sharing class CreateAndScheduleEmergencyAppointment {

    public class AppointmentRequest {
        @InvocableVariable(required=true description='Patient ID')
        public String patientABHAID;

        @InvocableVariable(required=true description='Requested appointment date')
        public Date appointmentDate;
    }

    public class AppointmentResponse {
        @InvocableVariable(required=true description='Created appointment ID')
        public String appointmentMsg;
    }

    @InvocableMethod(label='Schedule Emergency Appointment' description='Schedules an emergency appointment based on doctor availability')
    public static List<String> scheduleEmergencyAppointment(List<AppointmentRequest> requests) {
        List<Appointment__c> appointmentsToInsert = new List<Appointment__c>();
        AppointmentResponse response = new AppointmentResponse();
        List<String> appointmentSuccessMsg = new List<String>();
        String appointmentNumber = '';

        // Query for the emergency queues
        QueueSObject queueSObject = [SELECT Id, QueueId FROM QueueSObject WHERE Queue.Name LIKE 'Emergency%' LIMIT 1];

        for (AppointmentRequest request : requests) {
            // Query for available doctors based on the requested specialization and availability
            List<Doctor__c> availableDoctors = [
                SELECT Id, Name
                FROM Doctor__c
                WHERE Shift_Date__c = :request.appointmentDate
                LIMIT 1
            ];

            if (!availableDoctors.isEmpty()) {
                Doctor__c doctor = availableDoctors[0];

                // Check if an appointment already exists for the doctor and appointment date
                Appointment__c existingAppointment = [
                    SELECT Id, Name, Doctor_Assigned__c, 
                    Slot_Start__c, Slot_End__c
                    FROM Appointment__c
                    WHERE Slot_Start__c <= :request.appointmentDate
                    LIMIT 1
                ];

                if (existingAppointment == null) {
                    // Create the appointment record
                    Appointment__c appointment = new Appointment__c(
                        Patient__c = request.patientABHAID,
                        Doctor_Assigned__c = doctor.Id,
                        Slot_Start__c = request.appointmentDate,
                        Type_of_Appointment__c = 'Emergency',
                        OwnerId = queueSObject.Id
                    );
                    appointmentNumber = appointmentsToInsert.get(0).Name;
                    appointmentsToInsert.add(appointment);
                }
            }
        }

        // Insert appointment records
        if (!appointmentsToInsert.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.insert(appointmentsToInsert, false);

            // Iterate through each returned result
            for (Database.SaveResult saveResult : saveResults) {
                if (!saveResult.isSuccess()) {
                    // Operation failed, so get all errors
                    for (Database.Error err : saveResult.getErrors()) {
                        System.debug('Error scheduling appointment: ' + err.getMessage());
                    }
                }
            }

            response.appointmentMsg = 'Appointment scheduled successfully with Appointment Number: '+appointmentNumber;
            appointmentSuccessMsg.add(response.appointmentMsg);
        }

        return appointmentSuccessMsg;
    }
}