
{
  aws: {
    region: 'eu-north-1',
  },

  terraform: {
    backend: {
      // Pointlessly configure an alternate local terraform state location to
      // demonstrate how remote backends ~could~ be configured.
      path: std.extVar('PWD') + '/genfiles/alternate_terraform.tfstate'
    }
  }
}

